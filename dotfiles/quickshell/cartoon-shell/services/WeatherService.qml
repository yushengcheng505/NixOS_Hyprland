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

  readonly property string environmentApiKey: Quickshell.env("WEATHER_API_KEY") || ""
  property string fileApiKey: ""
  readonly property string apiKey: root.environmentApiKey || root.fileApiKey || Settings.weather.keyApi || ""
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

  property bool initialized: false
  property bool requestQueued: false
  property int requestAttempt: 0
  property string requestUrl: ""
  property string requestOutput: ""
  property string pendingApiKey: ""

  onApiKeyChanged: if (root.initialized) root.updateWeather()
  onLocationChanged: if (root.initialized) root.updateWeather()
  onLangChanged: if (root.initialized) root.updateWeather()

  function setError(code, message) {
    root.errorCode = Number(code || 0)
    root.errorMessage = String(message || LanguageService.t("weather", "unavailable"))
    root.loading = false
  }

  function curlConfig(url) {
    const escaped = String(url).replace(/[\u0000-\u001f\u007f]/g, ch => encodeURIComponent(ch))
      .replace(/\\/g, "\\\\").replace(/"/g, '\\"')
    return 'url = "' + escaped + '"\n'
  }

  function curlCommand(useProxy) {
    return ["curl", "--disable", "--silent", "--show-error", "--connect-timeout", "5", "--max-time", "15",
      "--proxy", useProxy ? "http://127.0.0.1:2080" : "", "--noproxy", useProxy ? "" : "*", "--config", "-"]
  }

  function sendRequest(process, url, useProxy) {
    process.requestConfig = root.curlConfig(url)
    process.command = root.curlCommand(useProxy)
    process.stdinEnabled = true
    process.running = true
  }

  function writeRequest(process) {
    process.write(process.requestConfig)
    process.requestConfig = ""
    process.stdinEnabled = false
  }

  function isRetryableApiError(code) {
    return Number(code) === 9999
  }

  function scheduleRetry(code, message) {
    root.errorCode = Number(code || 0)
    root.errorMessage = String(message || LanguageService.t("weather", "networkError"))
    root.loading = false
    retryTimer.restart()
  }

  function handleWeatherPayload(exitCode) {
    if (exitCode !== 0) {
      if (root.requestAttempt === 0) {
        root.requestAttempt = 1
        root.requestOutput = ""
        root.sendRequest(weatherProcess, root.requestUrl, false)
      } else {
        root.scheduleRetry(0, LanguageService.t("weather", "networkError"))
      }
      return
    }
    try {
      const parsed = JSON.parse(root.requestOutput)
      if (parsed && parsed.error) {
        if (root.isRetryableApiError(parsed.error.code))
          root.scheduleRetry(parsed.error.code, parsed.error.message)
        else
          root.setError(parsed.error.code, parsed.error.message)
        return
      }
      if (!parsed || !parsed.current || typeof parsed.current !== "object" || Array.isArray(parsed.current)) {
        root.scheduleRetry(0, LanguageService.t("weather", "invalidResponse"))
        return
      }
      if (!parsed.forecast || typeof parsed.forecast !== "object" || Array.isArray(parsed.forecast))
        parsed.forecast = { "forecastday": [] }
      if (!Array.isArray(parsed.forecast.forecastday))
        parsed.forecast.forecastday = []
      root.dataModel = parsed
      root.errorCode = 0
      root.errorMessage = ""
      root.lastUpdated = new Date().toISOString()
      root.loading = false
    } catch (e) {
      root.scheduleRetry(0, LanguageService.t("weather", "invalidResponse"))
    }
  }

  Process {
    id: weatherProcess
    property string requestConfig: ""
    running: false
    stdinEnabled: true
    onStarted: root.writeRequest(weatherProcess)
    onRunningChanged: {
      if (!running && root.loading && stdinEnabled) {
        root.requestQueued = false
        root.scheduleRetry(0, LanguageService.t("weather", "networkError"))
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (root.requestQueued) {
        root.requestQueued = false
        root.loading = false
        root.updateWeather()
      } else {
        root.handleWeatherPayload(exitStatus === 0 ? exitCode : -1)
      }
    }

    stdout: StdioCollector {
      onStreamFinished: root.requestOutput = String(text || "")
    }

    stderr: StdioCollector {}
  }

  Timer {
    id: retryTimer
    interval: 60000
    repeat: false
    onTriggered: root.updateWeather()
  }

  property string apiKeySaveError: ""

  Process {
    id: saveApiKeyProcess
    running: false
    stdinEnabled: true
    command: ["sh", "-c", "set -e; umask 077; mkdir -p \"$1\"; IFS= read -r api_key; printf '%s\\n' \"$api_key\" > \"$2\"; chmod 600 \"$2\"", "sh", Directories.shellConfig, Directories.weatherApiKeyPath]

    onStarted: {
      write(root.pendingApiKey + "\n")
      stdinEnabled = false
    }
    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0 || exitStatus !== 0)
        root.apiKeySaveError = "Could not save WeatherAPI key"
      else {
        root.apiKeySaveError = ""
        root.fileApiKey = root.pendingApiKey
      }
      root.pendingApiKey = ""
    }
    onRunningChanged: {
      if (!running && root.pendingApiKey && stdinEnabled) {
        root.apiKeySaveError = "Could not start WeatherAPI key writer"
        root.pendingApiKey = ""
      }
    }
    stderr: StdioCollector {}
  }

  FileView {
    id: apiKeyFile
    path: Directories.weatherApiKeyPath
    watchChanges: true
    printErrors: false
    onLoaded: root.fileApiKey = text().trim()
    onFileChanged: reload()
  }

  function setApiKey(key) {
    const normalized = String(key || "").trim()
    if (!normalized || !/^[A-Za-z0-9._-]+$/.test(normalized)) {
      root.apiKeySaveError = "Enter a valid WeatherAPI key"
      return false
    }
    if (saveApiKeyProcess.running || root.pendingApiKey) {
      root.apiKeySaveError = "WeatherAPI key save is still in progress"
      return false
    }
    root.apiKeySaveError = ""
    root.fileApiKey = normalized
    root.pendingApiKey = normalized
    saveApiKeyProcess.stdinEnabled = true
    saveApiKeyProcess.running = true
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
    if (!root.initialized)
      return
    retryTimer.stop()
    if (weatherProcess.running) {
      root.requestQueued = true
      return
    }
    if (!root.apiKey) {
      root.setError(0, LanguageService.t("weather", "apiKeyError"))
      return
    }
    if (!root.location) {
      root.setError(0, LanguageService.t("weather", "cityError"))
      return
    }
    root.requestUrl = "https://api.weatherapi.com/v1/forecast.json?key=" + encodeURIComponent(root.apiKey)
      + "&q=" + encodeURIComponent(root.location) + "&days=3&lang=" + encodeURIComponent(root.lang)
    root.requestAttempt = 0
    root.requestOutput = ""
    root.errorCode = 0
    root.errorMessage = ""
    root.loading = true
    root.sendRequest(weatherProcess, root.requestUrl, true)
  }

  Timer {
    interval: 1800000
    running: true
    repeat: true
    onTriggered: root.updateWeather()
  }

  Component.onCompleted: {
    root.initialized = true
    root.updateWeather()
  }
}
