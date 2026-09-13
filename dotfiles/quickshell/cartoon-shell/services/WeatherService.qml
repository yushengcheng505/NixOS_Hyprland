pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.commons
import qs.services

Singleton {
  id: root

  readonly property var defaultCurrent: ({
    "condition": {
      "text": LanguageService.t("weather", "unavailable"),
      "code": 1000
    },
    "temp_c": "--",
    "feelslike_c": "--",
    "humidity": "--",
    "wind_kph": "--",
    "pressure_mb": "--",
    "vis_km": "--",
    "uv": "--",
    "chance_of_rain": "--",
    "is_day": 1
  })

  property string apiKey: Quickshell.env("WEATHER_API_KEY") || Settings.weather.keyApi || ""
  property string location: Settings.weather.location || "Moscow,Russia"
  property string lang: LanguageService.normalizeLanguage(Settings.general.lang)
  property string errorMessage: ""
  property int errorCode: 0
  property bool loading: false
  property string lastUpdated: ""
  property var dataModel: ({
    "current": root.defaultCurrent,
    "forecast": { "forecastday": [] }
  })

  function setError(code, message) {
    root.errorCode = Number(code || 0)
    root.errorMessage = String(message || LanguageService.t("weather", "unavailable"))
    root.loading = false
  }

  Process {
    id: weatherProcess
    running: false

    stdout: StdioCollector {
      onStreamFinished: {
        const payload = String(text || "").trim()
        if (!payload) {
          root.setError(0, LanguageService.t("weather", "networkError"))
          return
        }
        try {
          const parsed = JSON.parse(payload)
          if (parsed.error) {
            root.setError(parsed.error.code, parsed.error.message)
            return
          }
          if (!parsed.current) {
            root.setError(0, LanguageService.t("weather", "invalidResponse"))
            return
          }
          if (!parsed.forecast)
            parsed.forecast = { "forecastday": [] }
          if (!Array.isArray(parsed.forecast.forecastday))
            parsed.forecast.forecastday = []
          root.dataModel = parsed
          root.errorCode = 0
          root.errorMessage = ""
          root.lastUpdated = new Date().toISOString()
          root.loading = false
        } catch (e) {
          root.setError(0, LanguageService.t("weather", "invalidResponse"))
          console.warn("Weather API response parse error:", e)
        }
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        const message = String(text || "").trim()
        if (message && !root.errorMessage)
          root.setError(0, message)
      }
    }
  }

  Process {
    id: saveApiKeyProcess
    running: false
    command: ["sh", "-c", "umask 077; mkdir -p \"$1\"; IFS= read -r api_key; printf '%s\\n' \"$api_key\" > \"$2\"; chmod 600 \"$2\"", "sh", Directories.shellConfig, Directories.weatherApiKeyPath]
  }

  FileView {
    id: apiKeyFile
    path: Directories.weatherApiKeyPath
    watchChanges: true
    printErrors: false

    onLoaded: {
      const fileKey = text().trim()
      if (!root.apiKey && fileKey) {
        root.apiKey = fileKey
        root.updateWeather()
      }
    }

    onFileChanged: reload()
  }

  function setApiKey(key) {
    const normalized = String(key || "").trim()
    if (!normalized || !/^[A-Za-z0-9._-]+$/.test(normalized))
      return false

    if (saveApiKeyProcess.running)
      saveApiKeyProcess.running = false
    saveApiKeyProcess.running = true
    saveApiKeyProcess.write(normalized + "\n")
    root.apiKey = normalized
    root.updateWeather()
    return true
  }

  function getWeatherIcon(code, isDay) {
    code = Number(code)
    const basePath = "weather/icon_weather_status"
    if (code === 1000)
      return isDay ? basePath + "/sun.png" : basePath + "/night.png"
    if (code === 1003)
      return isDay ? basePath + "/cloudy_sunny.png" : basePath + "/cloudy_night.png"
    if ([1006, 1009].includes(code))
      return basePath + "/cloudy.png"
    if (code === 1030)
      return basePath + "/mist.png"
    if ([1135, 1147].includes(code))
      return basePath + "/fog.png"
    if ((code >= 1063 && code <= 1195) || (code >= 1198 && code <= 1201))
      return basePath + "/rain.png"
    if (code >= 1204 && code <= 1264)
      return basePath + "/snowy.png"
    if (code >= 1273 && code <= 1282)
      return basePath + "/thunder.png"
    return basePath + "/rainbow.png"
  }

  function refresh() {
    updateWeather()
  }

  function updateWeather() {
    if (!root.apiKey) {
      root.setError(0, LanguageService.t("weather", "apiKeyError"))
      return
    }
    if (!root.location) {
      root.setError(0, LanguageService.t("weather", "cityError"))
      return
    }

    root.lang = LanguageService.normalizeLanguage(Settings.general.lang)
    root.errorCode = 0
    root.errorMessage = ""
    root.loading = true
    const url = "https://api.weatherapi.com/v1/forecast.json?key=" + encodeURIComponent(root.apiKey)
      + "&q=" + encodeURIComponent(root.location) + "&days=3&lang=" + root.lang
    weatherProcess.command = ["curl", "-sS", url]
    weatherProcess.running = true
  }

  Timer {
    interval: 1800000
    running: true
    repeat: true
    onTriggered: root.updateWeather()
  }

  Component.onCompleted: root.updateWeather()
}
