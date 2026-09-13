pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.commons

Singleton {
  id: root

  readonly property string languagesDir: Quickshell.shellDir + "/assets/i18n"
  readonly property string fallbackLang: "en"
  readonly property var supportedLanguages: ["en", "ru", "ja", "es"]

  property string currentLanguage: fallbackLang
  property var translations: ({})
  property var fallbackTranslations: ({})
  property bool loading: false
  property bool fallbackReady: false
  property string pendingLanguage: fallbackLang

  signal languageChanged(string lang)

  function normalizeLanguage(lang) {
    const value = String(lang || fallbackLang).split(/[-_]/)[0].toLowerCase();
    return supportedLanguages.indexOf(value) >= 0 ? value : fallbackLang;
  }

  function init() {
    const requested = normalizeLanguage(Settings.general.lang);
    if (Settings.general.lang !== requested)
      Settings.general.lang = requested;
    pendingLanguage = requested;
    fallbackReader.path = "";
    fallbackReader.path = languagesDir + "/" + fallbackLang + ".json";
  }

  function mergeTranslations(base, override) {
    if (!base || typeof base !== "object")
      return override || {};
    if (!override || typeof override !== "object")
      return base;

    const result = {};
    Object.keys(base).forEach(function (key) {
      const baseValue = base[key];
      const overrideValue = override[key];
      if (baseValue && typeof baseValue === "object" && !Array.isArray(baseValue))
        result[key] = mergeTranslations(baseValue, overrideValue);
      else
        result[key] = baseValue;
    });
    Object.keys(override).forEach(function (key) {
      if (!(key in result))
        result[key] = override[key];
      else if (override[key] && typeof override[key] === "object" && !Array.isArray(override[key]))
        result[key] = mergeTranslations(result[key], override[key]);
      else
        result[key] = override[key];
    });
    return result;
  }

  function loadLanguage(lang) {
    lang = normalizeLanguage(lang);
    pendingLanguage = lang;
    root.loading = true;
    if (fallbackReady) {
      languageReader.path = "";
      languageReader.path = languagesDir + "/" + lang + ".json";
    }
  }

  function changeLanguage(newLang) {
    const normalized = normalizeLanguage(newLang);
    if (normalized === currentLanguage && normalized === Settings.general.lang)
      return translations;

    Settings.general.lang = normalized;
    loadLanguage(normalized);
    return translations;
  }

  function t(section, key) {
    if (translations?.[section]?.[key])
      return translations[section][key];
    return key;
  }

  function getFallbackLanguage() {
    return {
      "settings": {
        "title": "Settings",
        "general": "General",
        "appearance": "Appearance",
        "network": "Network",
        "audio": "Audio",
        "performance": "Performance",
        "shortcuts": "Shortcuts",
        "system": "System"
      }
    };
  }

  FileView {
    id: fallbackReader
    watchChanges: true

    onLoaded: {
      try {
        const jsonText = text();
        root.fallbackTranslations = JSON.parse(jsonText);
      } catch (e) {
        console.error("English language parse error:", e);
        root.fallbackTranslations = root.getFallbackLanguage();
      }
      root.fallbackReady = true;
      root.loadLanguage(root.pendingLanguage);
    }

    onLoadFailed: {
      root.fallbackTranslations = root.getFallbackLanguage();
      root.fallbackReady = true;
      root.loadLanguage(root.pendingLanguage);
    }
  }

  FileView {
    id: languageReader
    watchChanges: true

    onLoaded: {
      try {
        const jsonText = text();
        if (!jsonText || jsonText === "")
          throw "Empty language file";

        root.currentLanguage = root.pendingLanguage;
        root.translations = root.mergeTranslations(root.fallbackTranslations, JSON.parse(jsonText));
      } catch (e) {
        console.error("Language parse error:", e);
        root.currentLanguage = root.fallbackLang;
        root.translations = root.fallbackTranslations || root.getFallbackLanguage();
      }

      root.loading = false;
      languageChanged(root.currentLanguage);
    }

    onLoadFailed: {
      root.currentLanguage = root.fallbackLang;
      root.translations = root.fallbackTranslations || root.getFallbackLanguage();
      root.loading = false;
      languageChanged(root.currentLanguage);
    }
  }

  Connections {
    target: Settings.general

    function onLangChanged() {
      Qt.callLater(function () {
        const normalized = root.normalizeLanguage(Settings.general.lang);
        if (Settings.general.lang !== normalized)
          Settings.general.lang = normalized;
        root.loadLanguage(normalized);
      });
    }
  }
}
