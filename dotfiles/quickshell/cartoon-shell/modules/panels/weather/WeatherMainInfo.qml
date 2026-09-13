import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.commons
import qs.components
import "." as Com

Item {
  id: root
  property real animationProgress: 0
  property bool showSettings: false
  readonly property var forecastDays: (WeatherService.dataModel && WeatherService.dataModel.forecast && Array.isArray(WeatherService.dataModel.forecast.forecastday)) ? WeatherService.dataModel.forecast.forecastday : []
  readonly property var hourlyTemperatures: root.buildHourlyTemperatures()

  function buildHourlyTemperatures() {
    if (root.forecastDays.length === 0 || !root.forecastDays[0].hour)
      return []
    var hours = root.forecastDays[0].hour
    var result = []
    for (var i = 0; i < hours.length; i += 2) {
      if (hours[i] && hours[i].temp_c !== undefined)
        result.push(Number(hours[i].temp_c))
    }
    return result
  }

  Com.WeatherSettings {
    id: weatherSettings
    anchors.fill: parent
    showSettings: root.showSettings
    visible: root.showSettings
  }

  // Nội dung chính
  RowLayout {
    id: weatherContent
    anchors.fill: parent
    spacing: ScalerService.s(50)
    visible: !root.showSettings

    // Left Column - Current Weather
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.preferredWidth: root.width * 0.5

      ColumnLayout {
        spacing: ScalerService.s(24)
        anchors.fill: parent
        anchors.topMargin: ScalerService.s(16)

        Com.WeatherCurrentInfo {
          animationProgress: root.animationProgress
          Layout.fillWidth: true
        }

        Com.WeatherDateTimeInfo {
          animationProgress: root.animationProgress
          Layout.fillWidth: true
        }

        Com.WeatherLocationInfo {
          animationProgress: root.animationProgress
          Layout.fillWidth: true
        }

        Com.WeatherDetailsGrid {
          animationProgress: root.animationProgress
          Layout.fillWidth: true
        }

        Com.TemperatureChart {
          Layout.preferredHeight: ScalerService.s(200)
          Layout.fillWidth: true
          Layout.topMargin: ScalerService.s(8)
          temperatures: root.hourlyTemperatures
        }
      }
    }

    // Right Column - Forecast
    Item {
      Layout.fillHeight: true
      Layout.fillWidth: true
      Layout.preferredWidth: root.width * 0.5

      ColumnLayout {
        anchors.fill: parent
        spacing: ScalerService.s(20)
        anchors.topMargin: ScalerService.s(16)

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: ScalerService.s(40)

          CustomText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            name: LanguageService.t("weather", "hourlyForecast")
            size: "large"
            isBold: true
            textColor: theme.primary.foreground
          }

          CustomText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            name: LanguageService.t("weather", "threeDays")
            isBold: true
            textColor: theme.button.text
          }
        }

        ScrollView {
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
          ScrollBar.vertical.policy: ScrollBar.AsNeeded

          ListView {
            id: forecastListView
            spacing: ScalerService.s(12)
            orientation: ListView.Vertical
            model: root.forecastDays
            width: parent.width

            delegate: Rectangle {
              width: forecastListView.width - ScalerService.s(20)
              height: ScalerService.s(100)
              radius: ScalerService.s(16)
              color: Qt.alpha(theme.button.background, 0.4)
              opacity: 0.9

              RowLayout {
                anchors.fill: parent
                anchors.margins: ScalerService.s(12)
                spacing: ScalerService.s(12)

                IconImage {
                  path: WeatherService.getWeatherIcon(modelData.day.condition.code)
                  size: "2xl"
                  Layout.preferredWidth: ScalerService.s(48)
                  Layout.preferredHeight: ScalerService.s(48)
                }

                ColumnLayout {
                  Layout.preferredWidth: ScalerService.s(70)
                  spacing: ScalerService.s(4)

                  CustomText {
                    name: getDayName(modelData.date)
                    size: "medium"
                    isBold: true
                    textColor: theme.primary.foreground
                  }

                  CustomText {
                    name: formatDate(modelData.date)
                    size: "xsmall"
                    textColor: theme.primary.dim_foreground
                  }
                }

                Item {
                  Layout.fillWidth: true
                  Layout.preferredHeight: ScalerService.s(50)

                  CustomText {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    name: modelData.day.condition.text.length > 12
                    ? `${modelData.day.condition.text.slice(0, 12)}...`
                    : modelData.day.condition.text
                    textColor: theme.primary.dim_foreground
                    elide: Text.ElideRight
                  }
                }

                ColumnLayout {
                  Layout.preferredWidth: ScalerService.s(80)
                  spacing: ScalerService.s(4)

                  CustomText {
                    name: `${Math.round(modelData.day.maxtemp_c)}°C`
                    size: "medium"
                    isBold: true
                    textColor: theme.normal.red
                    horizontalAlignment: Text.AlignRight
                  }

                  CustomText {
                    name: `${Math.round(modelData.day.mintemp_c)}°C`
                    size: "medium"
                    isBold: true
                    textColor: theme.normal.blue
                    horizontalAlignment: Text.AlignRight
                  }
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
              }
            }
          }
        }
      }
    }
  }

  Rectangle {
    visible: !root.showSettings && WeatherService.errorMessage !== ""
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    z: 10
    height: visible ? ScalerService.s(42) : 0
    radius: ScalerService.s(10)
    color: Qt.alpha(theme.normal.red, 0.18)
    border.color: Qt.alpha(theme.normal.red, 0.55)
    Text {
      anchors.fill: parent
      anchors.margins: ScalerService.s(10)
      text: WeatherService.errorCode > 0 ? (WeatherService.errorMessage + " (" + WeatherService.errorCode + ")") : WeatherService.errorMessage
      color: theme.primary.foreground
      font.pixelSize: ScalerService.s(13)
      elide: Text.ElideRight
      verticalAlignment: Text.AlignVCenter
    }
  }

  // Settings Content

  function getDayName(dateString) {
    var date = new Date(dateString)
    const dayData = lang?.dateFormat?.day;
    const days = dayData ? [
    dayData.sunday || "Sunday",
    dayData.monday || "Monday",
    dayData.tuesday || "Tuesday",
    dayData.wednesday || "Wednesday",
    dayData.thursday || "Thursday",
    dayData.friday || "Friday",
    dayData.saturday || "Saturday"
    ] : [
    "Sunday", "Monday", "Tuesday", "Wednesday",
    "Thursday", "Friday", "Saturday"
    ];
    return days[date.getDay()]
  }

  function formatDate(dateString) {
    var date = new Date(dateString)
    return `${date.getDate()}/${date.getMonth() + 1}`
  }
}
