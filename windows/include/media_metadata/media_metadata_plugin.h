#ifndef FLUTTER_PLUGIN_MEDIA_METADATA_PLUGIN_H_
#define FLUTTER_PLUGIN_MEDIA_METADATA_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <memory>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

namespace media_metadata {

// CORRECTION : Suppression de FLUTTER_PLUGIN_EXPORT ici pour éviter le warning C4275
class MediaMetadataPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  MediaMetadataPlugin();
  virtual ~MediaMetadataPlugin();

  // Empêcher la copie ou le déplacement
  MediaMetadataPlugin(const MediaMetadataPlugin&) = delete;
  MediaMetadataPlugin& operator=(const MediaMetadataPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace media_metadata

#if defined(__cplusplus)
extern "C" {
#endif

// On garde l'exportation sur la fonction C, indispensable à Flutter
FLUTTER_PLUGIN_EXPORT void MediaMetadataPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_MEDIA_METADATA_PLUGIN_H_