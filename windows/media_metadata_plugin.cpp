// media_metadata_plugin.cpp
// Windows implementation using Shell Property Store (works for mp3, mp4, mkv, etc.)
// and WIC (Windows Imaging Component) for image files (heic, webp).

#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0601 // Windows 7 ou supérieur
#endif

#include "include/media_metadata/media_metadata_plugin.h"

// clang-format off
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <propsys.h>
#include <propkey.h>
#include <propvarutil.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <wincodec.h>
// clang-format on

#pragma comment(lib, "propsys.lib")
#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "mfplat.lib")
#pragma comment(lib, "mfreadwrite.lib")
#pragma comment(lib, "mfuuid.lib")
#pragma comment(lib, "windowscodecs.lib")

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <codecvt>
#include <locale>
#include <memory>
#include <sstream>
#include <string>
#include <vector>
#include <algorithm>

namespace media_metadata {

namespace {

// Helper: wide string to UTF-8
std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) return {};
  int size = WideCharToMultiByte(CP_UTF8, 0, wide.data(), (int)wide.size(),
                                 nullptr, 0, nullptr, nullptr);
  std::string result(size, 0);
  WideCharToMultiByte(CP_UTF8, 0, wide.data(), (int)wide.size(),
                      result.data(), size, nullptr, nullptr);
  return result;
}

// Helper: UTF-8 to wide string
std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return {};
  int size = MultiByteToWideChar(CP_UTF8, 0, utf8.data(), (int)utf8.size(),
                                 nullptr, 0);
  std::wstring result(size, 0);
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), (int)utf8.size(),
                      result.data(), size);
  return result;
}

// Helper: get string property from IPropertyStore
std::optional<std::string> GetStringProp(IPropertyStore* store,
                                         const PROPERTYKEY& key) {
  PROPVARIANT pv;
  PropVariantInit(&pv);
  if (SUCCEEDED(store->GetValue(key, &pv))) {
    if (pv.vt == VT_LPWSTR && pv.pwszVal) {
      auto result = WideToUtf8(pv.pwszVal);
      PropVariantClear(&pv);
      if (!result.empty()) return result;
    }
  }
  PropVariantClear(&pv);
  return std::nullopt;
}

// Helper: get uint32 property
std::optional<int32_t> GetUInt32Prop(IPropertyStore* store,
                                     const PROPERTYKEY& key) {
  PROPVARIANT pv;
  PropVariantInit(&pv);
  if (SUCCEEDED(store->GetValue(key, &pv))) {
    UINT32 val = 0;
    if (SUCCEEDED(PropVariantToUInt32(pv, &val))) {
      PropVariantClear(&pv);
      return (int32_t)val;
    }
  }
  PropVariantClear(&pv);
  return std::nullopt;
}

// Helper: get uint64 property
std::optional<int64_t> GetUInt64Prop(IPropertyStore* store,
                                     const PROPERTYKEY& key) {
  PROPVARIANT pv;
  PropVariantInit(&pv);
  if (SUCCEEDED(store->GetValue(key, &pv))) {
    UINT64 val = 0;
    if (SUCCEEDED(PropVariantToUInt64(pv, &val))) {
      PropVariantClear(&pv);
      return (int64_t)val;
    }
  }
  PropVariantClear(&pv);
  return std::nullopt;
}

bool SetStringProp(IPropertyStore* store, const PROPERTYKEY& key,
                   const std::optional<std::string>& value) {
  if (!value.has_value()) return true;
  PROPVARIANT pv;
  PropVariantInit(&pv);
  const std::wstring wide = Utf8ToWide(*value);
  HRESULT hr = InitPropVariantFromString(wide.c_str(), &pv);
  if (SUCCEEDED(hr)) {
    store->SetValue(key, pv);
  }
  PropVariantClear(&pv);
  return true;
}

bool SetUInt32Prop(IPropertyStore* store, const PROPERTYKEY& key,
                   const std::optional<int32_t>& value) {
  if (!value.has_value()) return true;
  PROPVARIANT pv;
  PropVariantInit(&pv);
  HRESULT hr = InitPropVariantFromUInt32((UINT32)*value, &pv);
  if (SUCCEEDED(hr)) {
    store->SetValue(key, pv);
  }
  PropVariantClear(&pv);
  return true;
}

bool SetImageProp(IPropertyStore* store, const PROPERTYKEY& key,
                  const std::optional<std::vector<uint8_t>>& bytes) {
  if (!bytes.has_value() || bytes->empty()) return true;

  IStream* pStream = nullptr;
  HRESULT hr = CreateStreamOnHGlobal(nullptr, TRUE, &pStream);
  if (FAILED(hr)) return false;

  ULONG bytesWritten = 0;
  hr = pStream->Write(bytes->data(), static_cast<ULONG>(bytes->size()), &bytesWritten);
  if (FAILED(hr)) {
    pStream->Release();
    return false;
  }

  LARGE_INTEGER liZero = {0};
  pStream->Seek(liZero, STREAM_SEEK_SET, nullptr);

  PROPVARIANT pv;
  PropVariantInit(&pv);
  
  pv.vt = VT_UNKNOWN;
  hr = pStream->QueryInterface(IID_PPV_ARGS(&pv.punkVal));
  
  if (SUCCEEDED(hr)) {
    hr = store->SetValue(key, pv);
  }

  PropVariantClear(&pv);
  pStream->Release();
  return SUCCEEDED(hr);
}

bool WriteMediaMetadata(const std::wstring& file_path,
                        const flutter::EncodableMap& metadata) {
  // Extraction et mise en minuscule sécurisée de l'extension
  std::wstring ext = L"";
  size_t dot_idx = file_path.find_last_of(L".");
  if (dot_idx != std::wstring::npos) {
    ext = file_path.substr(dot_idx + 1);
    std::transform(ext.begin(), ext.end(), ext.begin(), ::towlower);
  }
  
  bool isAudio = (ext == L"mp3" || ext == L"m4a" || ext == L"flac" || ext == L"wav" || ext == L"wma" || ext == L"aac");

  // Pour les vidéos, GPS_READWRITE | GPS_FASTPROPERTIESONLY force Windows à accepter les modifications de tags
  GETPROPERTYSTOREFLAGS flags = isAudio ? GPS_READWRITE : static_cast<GETPROPERTYSTOREFLAGS>(GPS_READWRITE | GPS_FASTPROPERTIESONLY);

  IPropertyStore* pStore = nullptr;
  HRESULT hr = SHGetPropertyStoreFromParsingName(file_path.c_str(), nullptr, flags, IID_PPV_ARGS(&pStore));
  if (FAILED(hr) || !pStore) return false;

  auto getString = [&](const flutter::EncodableValue& key) -> std::optional<std::string> {
    auto it = metadata.find(key);
    if (it == metadata.end()) return std::nullopt;
    if (auto str = std::get_if<std::string>(&it->second)) return *str;
    return std::nullopt;
  };

  auto getInt = [&](const flutter::EncodableValue& key) -> std::optional<int32_t> {
    auto it = metadata.find(key);
    if (it == metadata.end()) return std::nullopt;
    if (auto val = std::get_if<int32_t>(&it->second)) return *val;
    if (auto val64 = std::get_if<int64_t>(&it->second)) return static_cast<int32_t>(*val64);
    return std::nullopt;
  };

  auto getImageBytes = [&](const flutter::EncodableValue& key) -> std::optional<std::vector<uint8_t>> {
    auto it = metadata.find(key);
    if (it == metadata.end()) return std::nullopt;
    if (auto bytes = std::get_if<std::vector<uint8_t>>(&it->second)) return *bytes;
    return std::nullopt;
  };

  // Propriétés globales (Audio + Vidéo)
  SetStringProp(pStore, PKEY_Title, getString("title"));
  SetUInt32Prop(pStore, PKEY_Media_Year, getInt("year"));

  if (isAudio) {
    SetStringProp(pStore, PKEY_Music_Artist, getString("artist"));
    SetStringProp(pStore, PKEY_Music_AlbumTitle, getString("album"));
    SetStringProp(pStore, PKEY_Music_AlbumArtist, getString("albumArtist"));
    SetStringProp(pStore, PKEY_Music_Genre, getString("genre"));
    SetUInt32Prop(pStore, PKEY_Music_TrackNumber, getInt("trackNumber"));
    SetUInt32Prop(pStore, PKEY_Music_PartOfSet, getInt("discNumber"));
    
    // Écriture de la pochette d'album (uniquement sur l'audio)
    auto imgData = getImageBytes("imageData");
    if (imgData.has_value() && !imgData->empty()) {
      SetImageProp(pStore, PKEY_ThumbnailStream, imgData);
    }
  } else {
    // Clés alternatives spécifiques pour la vidéo si disponibles
    SetStringProp(pStore, PKEY_Comment, getString("genre"));
  }

  hr = pStore->Commit();
  pStore->Release();

  return SUCCEEDED(hr);
}

flutter::EncodableMap ReadMediaMetadata(const std::wstring& file_path) {
  flutter::EncodableMap result;
  result[flutter::EncodableValue("title")] = flutter::EncodableValue();
  result[flutter::EncodableValue("duration")] = flutter::EncodableValue();
  result[flutter::EncodableValue("artist")] = flutter::EncodableValue();
  result[flutter::EncodableValue("album")] = flutter::EncodableValue();
  result[flutter::EncodableValue("albumArtist")] = flutter::EncodableValue();
  result[flutter::EncodableValue("trackNumber")] = flutter::EncodableValue();
  result[flutter::EncodableValue("trackTotal")] = flutter::EncodableValue();
  result[flutter::EncodableValue("discNumber")] = flutter::EncodableValue();
  result[flutter::EncodableValue("discTotal")] = flutter::EncodableValue();
  result[flutter::EncodableValue("year")] = flutter::EncodableValue();
  result[flutter::EncodableValue("genre")] = flutter::EncodableValue();
  result[flutter::EncodableValue("imageData")] = flutter::EncodableValue();

  WIN32_FILE_ATTRIBUTE_DATA fad;
  if (GetFileAttributesExW(file_path.c_str(), GetFileExInfoStandard, &fad)) {
    int64_t size = ((int64_t)fad.nFileSizeHigh << 32) | fad.nFileSizeLow;
    result[flutter::EncodableValue("fileSize")] = flutter::EncodableValue(size);
  } else {
    result[flutter::EncodableValue("fileSize")] = flutter::EncodableValue();
  }

  IPropertyStore* pStore = nullptr;
  HRESULT hr = SHGetPropertyStoreFromParsingName(file_path.c_str(), nullptr, GPS_DEFAULT, IID_PPV_ARGS(&pStore));

  if (SUCCEEDED(hr) && pStore) {
    if (auto v = GetStringProp(pStore, PKEY_Title))
      result[flutter::EncodableValue("title")] = flutter::EncodableValue(*v);

    if (auto v = GetStringProp(pStore, PKEY_Music_Artist))
      result[flutter::EncodableValue("artist")] = flutter::EncodableValue(*v);

    if (auto v = GetStringProp(pStore, PKEY_Music_AlbumTitle))
      result[flutter::EncodableValue("album")] = flutter::EncodableValue(*v);

    if (auto v = GetStringProp(pStore, PKEY_Music_AlbumArtist))
      result[flutter::EncodableValue("albumArtist")] = flutter::EncodableValue(*v);

    if (auto v = GetUInt32Prop(pStore, PKEY_Music_TrackNumber))
      result[flutter::EncodableValue("trackNumber")] = flutter::EncodableValue(*v);

    if (auto v = GetUInt32Prop(pStore, PKEY_Music_PartOfSet))
      result[flutter::EncodableValue("discNumber")] = flutter::EncodableValue(*v);

    if (auto v = GetUInt32Prop(pStore, PKEY_Media_Year))
      result[flutter::EncodableValue("year")] = flutter::EncodableValue(*v);

    if (auto v = GetStringProp(pStore, PKEY_Music_Genre))
      result[flutter::EncodableValue("genre")] = flutter::EncodableValue(*v);

    if (auto v = GetUInt64Prop(pStore, PKEY_Media_Duration)) {
      int64_t ms = (int64_t)(*v / 10000LL);
      result[flutter::EncodableValue("duration")] = flutter::EncodableValue(ms);
    }

    pStore->Release();
  }

  IShellItem* pItem = nullptr;
  if (SUCCEEDED(SHCreateItemFromParsingName(file_path.c_str(), nullptr, IID_PPV_ARGS(&pItem)))) {
    IShellItemImageFactory* pFactory = nullptr;
    if (SUCCEEDED(pItem->QueryInterface(IID_PPV_ARGS(&pFactory)))) {
      HBITMAP hbm = nullptr;
      SIZE sz = {256, 256};
      if (SUCCEEDED(pFactory->GetImage(sz, SIIGBF_BIGGERSIZEOK, &hbm)) && hbm) {
        IWICImagingFactory* pWicFactory = nullptr;
        if (SUCCEEDED(CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&pWicFactory)))) {
          IWICBitmap* pWicBitmap = nullptr;
          if (SUCCEEDED(pWicFactory->CreateBitmapFromHBITMAP(hbm, nullptr, WICBitmapUseAlpha, &pWicBitmap))) {
            IStream* pStream = nullptr;
            if (SUCCEEDED(CreateStreamOnHGlobal(nullptr, TRUE, &pStream))) {
              IWICBitmapEncoder* pEncoder = nullptr;
              if (SUCCEEDED(pWicFactory->CreateEncoder(GUID_ContainerFormatPng, nullptr, &pEncoder))) {
                if (SUCCEEDED(pEncoder->Initialize(pStream, WICBitmapEncoderNoCache))) {
                  IWICBitmapFrameEncode* pFrame = nullptr;
                  IPropertyBag2* pBag = nullptr;
                  if (SUCCEEDED(pEncoder->CreateNewFrame(&pFrame, &pBag))) {
                    if (SUCCEEDED(pFrame->Initialize(pBag))) {
                      pFrame->WriteSource(pWicBitmap, nullptr);
                      pFrame->Commit();
                      pEncoder->Commit();

                      HGLOBAL hg = nullptr;
                      GetHGlobalFromStream(pStream, &hg);
                      if (hg) {
                        SIZE_T size_bytes = GlobalSize(hg);
                        void* ptr = GlobalLock(hg);
                        if (ptr && size_bytes > 0) {
                          std::vector<uint8_t> bytes((uint8_t*)ptr, (uint8_t*)ptr + size_bytes);
                          result[flutter::EncodableValue("imageData")] = flutter::EncodableValue(bytes);
                        }
                        GlobalUnlock(hg);
                      }
                    }
                    if (pBag) pBag->Release();
                    pFrame->Release();
                  }
                }
                pEncoder->Release();
              }
              pStream->Release();
            }
            pWicBitmap->Release();
          }
          pWicFactory->Release();
        }
        DeleteObject(hbm);
      }
      pFactory->Release();
    }
    pItem->Release();
  }

  return result;
}

}  // namespace

void MediaMetadataPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "media_metadata", &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<MediaMetadataPlugin>();
  channel->SetMethodCallHandler([plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}

MediaMetadataPlugin::MediaMetadataPlugin() {
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  MFStartup(MF_VERSION);
}

MediaMetadataPlugin::~MediaMetadataPlugin() {
  MFShutdown();
  CoUninitialize();
}

void MediaMetadataPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string method = method_call.method_name();
  const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
  if (!args) {
    result->Error("INVALID_ARGUMENT", "Expected map argument");
    return;
  }

  if (method == "readMetadata") {
    auto it = args->find(flutter::EncodableValue("filePath"));
    if (it == args->end()) {
      result->Error("INVALID_ARGUMENT", "filePath is required");
      return;
    }
    const auto& file_path_utf8 = std::get<std::string>(it->second);
    std::wstring wide_path = Utf8ToWide(file_path_utf8);
    auto metadata = ReadMediaMetadata(wide_path);
    result->Success(flutter::EncodableValue(metadata));
  } else if (method == "writeMetadata") {
    auto itPath = args->find(flutter::EncodableValue("filePath"));
    auto itMeta = args->find(flutter::EncodableValue("metadata"));
    if (itPath == args->end() || itMeta == args->end()) {
      result->Error("INVALID_ARGUMENT", "filePath and metadata are required");
      return;
    }
    const auto& file_path_utf8 = std::get<std::string>(itPath->second);
    const auto* metadata_map = std::get_if<flutter::EncodableMap>(&itMeta->second);
    if (!metadata_map) {
      result->Error("INVALID_ARGUMENT", "metadata must be a map");
      return;
    }
    std::wstring wide_path = Utf8ToWide(file_path_utf8);
    bool success = WriteMediaMetadata(wide_path, *metadata_map);
    result->Success(flutter::EncodableValue(success));
  } else {
    result->NotImplemented();
  }
}

}  // namespace media_metadata

void MediaMetadataPluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
  media_metadata::MediaMetadataPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}