#include "include/media_metadata/media_metadata_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "include/media_metadata/media_metadata_plugin.h"

void MediaMetadataPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  media_metadata::MediaMetadataPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}