// media_metadata_plugin.cc — Linux implementation
// Uses TagLib when available (install: apt install libtag1-dev)
// Falls back to reading basic file info otherwise.

#include "include/media_metadata/media_metadata_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/stat.h>

#ifdef HAS_TAGLIB
#include <taglib/fileref.h>
#include <taglib/tag.h>
#include <taglib/audioproperties.h>
#include <taglib/attachedpictureframe.h>
#include <taglib/id3v2tag.h>
#include <taglib/mpegfile.h>
#include <taglib/flacfile.h>
#include <taglib/mp4file.h>
#include <taglib/mp4tag.h>
#endif

#define MEDIA_METADATA_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), media_metadata_plugin_get_type(), \
                               MediaMetadataPlugin))

struct _MediaMetadataPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(MediaMetadataPlugin, media_metadata_plugin, g_object_get_type())

static int64_t get_file_size(const char* path) {
  struct stat st;
  if (stat(path, &st) == 0) return (int64_t)st.st_size;
  return 0;
}

static FlValue* read_metadata(const char* file_path) {
  FlValue* result = fl_value_new_map();
  fl_value_set_string(result, "title", fl_value_new_null());
  fl_value_set_string(result, "duration", fl_value_new_null());
  fl_value_set_string(result, "artist", fl_value_new_null());
  fl_value_set_string(result, "album", fl_value_new_null());
  fl_value_set_string(result, "albumArtist", fl_value_new_null());
  fl_value_set_string(result, "trackNumber", fl_value_new_null());
  fl_value_set_string(result, "trackTotal", fl_value_new_null());
  fl_value_set_string(result, "discNumber", fl_value_new_null());
  fl_value_set_string(result, "discTotal", fl_value_new_null());
  fl_value_set_string(result, "year", fl_value_new_null());
  fl_value_set_string(result, "genre", fl_value_new_null());
  fl_value_set_string(result, "imageData", fl_value_new_null());

  int64_t size = get_file_size(file_path);
  fl_value_set_string(result, "fileSize", fl_value_new_int(size));

#ifdef HAS_TAGLIB
  TagLib::FileRef f(file_path);
  if (!f.isNull() && f.tag()) {
    TagLib::Tag* tag = f.tag();

    if (!tag->title().isEmpty())
      fl_value_set_string(result, "title",
                          fl_value_new_string(tag->title().toCString(true)));
    if (!tag->artist().isEmpty())
      fl_value_set_string(result, "artist",
                          fl_value_new_string(tag->artist().toCString(true)));
    if (!tag->album().isEmpty())
      fl_value_set_string(result, "album",
                          fl_value_new_string(tag->album().toCString(true)));
    if (!tag->genre().isEmpty())
      fl_value_set_string(result, "genre",
                          fl_value_new_string(tag->genre().toCString(true)));
    if (tag->year() > 0)
      fl_value_set_string(result, "year", fl_value_new_int(tag->year()));
    if (tag->track() > 0)
      fl_value_set_string(result, "trackNumber",
                          fl_value_new_int(tag->track()));
  }

  if (!f.isNull() && f.audioProperties()) {
    int ms = f.audioProperties()->lengthInMilliseconds();
    if (ms > 0)
      fl_value_set_string(result, "duration", fl_value_new_int(ms));
  }

  // Try to get album art from ID3v2
  TagLib::MPEG::File* mpeg =
      dynamic_cast<TagLib::MPEG::File*>(f.file());
  if (mpeg && mpeg->ID3v2Tag()) {
    auto frames =
        mpeg->ID3v2Tag()->frameListMap()["APIC"];
    if (!frames.isEmpty()) {
      auto* frame =
          dynamic_cast<TagLib::ID3v2::AttachedPictureFrame*>(frames.front());
      if (frame) {
        auto pic = frame->picture();
        FlValue* list = fl_value_new_list();
        for (char c : pic) {
          fl_value_append(list, fl_value_new_int((uint8_t)c));
        }
        fl_value_set_string(result, "imageData", list);
      }
    }
  }
#endif

  return result;
}

static bool write_metadata(const char* file_path, FlValue* metadata_map) {
#ifdef HAS_TAGLIB
  TagLib::FileRef f(file_path);
  if (f.isNull() || !f.tag()) {
    return false;
  }
  TagLib::Tag* tag = f.tag();

  auto maybeString = [&](const char* key) -> const char* {
    FlValue* value = fl_value_lookup_string(metadata_map, key);
    if (!value || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
      return nullptr;
    }
    return fl_value_get_string(value);
  };

  auto maybeInt = [&](const char* key) -> int {
    FlValue* value = fl_value_lookup_string(metadata_map, key);
    if (!value) return 0;
    if (fl_value_get_type(value) == FL_VALUE_TYPE_INT) {
      return (int)fl_value_get_int(value);
    }
    return 0;
  };

  if (const char* title = maybeString("title")) {
    tag->setTitle(title);
  }
  if (const char* artist = maybeString("artist")) {
    tag->setArtist(artist);
  }
  if (const char* album = maybeString("album")) {
    tag->setAlbum(album);
  }
  if (const char* genre = maybeString("genre")) {
    tag->setGenre(genre);
  }
  int year = maybeInt("year");
  if (year > 0) {
    tag->setYear(year);
  }
  int track = maybeInt("trackNumber");
  if (track > 0) {
    tag->setTrack(track);
  }
  return f.save();
#else
  return false;
#endif
}

static void media_metadata_plugin_handle_method_call(
    MediaMetadataPlugin* self, FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "readMetadata") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* path_val = fl_value_lookup_string(args, "filePath");
    if (!path_val || fl_value_get_type(path_val) != FL_VALUE_TYPE_STRING) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "INVALID_ARGUMENT", "filePath is required", nullptr));
    } else {
      const char* file_path = fl_value_get_string(path_val);
      FlValue* metadata = read_metadata(file_path);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(metadata));
    }
  } else if (strcmp(method, "writeMetadata") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* path_val = fl_value_lookup_string(args, "filePath");
    FlValue* metadata_val = fl_value_lookup_string(args, "metadata");
    if (!path_val || fl_value_get_type(path_val) != FL_VALUE_TYPE_STRING ||
        !metadata_val || fl_value_get_type(metadata_val) != FL_VALUE_TYPE_MAP) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "INVALID_ARGUMENT", "filePath and metadata are required", nullptr));
    } else {
      const char* file_path = fl_value_get_string(path_val);
      bool success = write_metadata(file_path, metadata_val);
      response = FL_METHOD_RESPONSE(
          fl_method_success_response_new(fl_value_new_bool(success)));
    }
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void media_metadata_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(media_metadata_plugin_parent_class)->dispose(object);
}

static void media_metadata_plugin_class_init(
    MediaMetadataPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = media_metadata_plugin_dispose;
}

static void media_metadata_plugin_init(MediaMetadataPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                            gpointer user_data) {
  MediaMetadataPlugin* plugin = MEDIA_METADATA_PLUGIN(user_data);
  media_metadata_plugin_handle_method_call(plugin, method_call);
}

void media_metadata_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  MediaMetadataPlugin* plugin = MEDIA_METADATA_PLUGIN(
      g_object_new(media_metadata_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "media_metadata",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
