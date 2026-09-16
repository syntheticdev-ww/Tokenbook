#import <AppKit/AppKit.h>
#include <stdint.h>
#include <stdlib.h>
#include "gdextension_interface.h"

// The bridge touches only an NSWindow owned by this process. It does not use
// accessibility, capture other applications, or modify the Codex process.
static GDExtensionInterfaceGetProcAddress api;
static GDExtensionClassLibraryPtr library;
static GDExtensionInterfaceClassdbConstructObject2 construct;
static GDExtensionInterfaceObjectSetInstance set_instance;
static GDExtensionTypeFromVariantConstructorFunc to_int;
static GDExtensionVariantFromTypeConstructorFunc from_bool;
static GDExtensionInterfaceVariantGetType variant_type;
static uint64_t class_name, base_name, method_name, empty_name, empty_string;

static GDExtensionObjectPtr create_instance(void *data, GDExtensionBool notify) {
    (void)data; (void)notify;
    GDExtensionObjectPtr object = construct(&base_name);
    set_instance(object, &class_name, calloc(1, 1));
    return object;
}

static void free_instance(void *data, GDExtensionClassInstancePtr instance) {
    (void)data;
    free(instance);
}

static void command(void *data, GDExtensionClassInstancePtr instance,
        const GDExtensionConstVariantPtr *args, GDExtensionInt count,
        GDExtensionVariantPtr result, GDExtensionCallError *error) {
    (void)data; (void)instance;
    GDExtensionBool visible = 0;
    error->error = GDEXTENSION_CALL_OK;
    if (count != 2 || variant_type(args[0]) != GDEXTENSION_VARIANT_TYPE_INT ||
            variant_type(args[1]) != GDEXTENSION_VARIANT_TYPE_INT) {
        error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
        from_bool(result, &visible);
        return;
    }
    int64_t handle = 0, operation = 0;
    to_int(&handle, (GDExtensionVariantPtr)args[0]);
    to_int(&operation, (GDExtensionVariantPtr)args[1]);
    if ([NSThread isMainThread]) {
        for (NSWindow *window in NSApp.windows) {
            if ((uintptr_t)(__bridge void *)window != (uintptr_t)handle) continue;
            switch (operation) {
                case 0:
                    window.hidesOnDeactivate = NO;
                    window.level = NSFloatingWindowLevel;
                    window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                        NSWindowCollectionBehaviorFullScreenAuxiliary;
                    break;
                case 1: [window orderOut:nil]; break;
                case 2: [window orderFrontRegardless]; break;
                case 3: break; // Query actual native visibility, not a shadow flag.
                default: break;
            }
            visible = window.isVisible;
            break;
        }
    }
    from_bool(result, &visible);
}

static void initialize(void *data, GDExtensionInitializationLevel level) {
    (void)data;
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    GDExtensionInterfaceStringNameNewWithLatin1Chars name_new =
        (GDExtensionInterfaceStringNameNewWithLatin1Chars)api("string_name_new_with_latin1_chars");
    GDExtensionInterfaceStringNewWithUtf8Chars string_new =
        (GDExtensionInterfaceStringNewWithUtf8Chars)api("string_new_with_utf8_chars");
    name_new(&class_name, "TokenbookNativeWindow", 0);
    name_new(&base_name, "RefCounted", 0);
    name_new(&method_name, "command", 0);
    name_new(&empty_name, "", 0);
    string_new(&empty_string, "");
    construct = (GDExtensionInterfaceClassdbConstructObject2)api("classdb_construct_object2");
    set_instance = (GDExtensionInterfaceObjectSetInstance)api("object_set_instance");
    variant_type = (GDExtensionInterfaceVariantGetType)api("variant_get_type");
    to_int = ((GDExtensionInterfaceGetVariantToTypeConstructor)api("get_variant_to_type_constructor"))(GDEXTENSION_VARIANT_TYPE_INT);
    from_bool = ((GDExtensionInterfaceGetVariantFromTypeConstructor)api("get_variant_from_type_constructor"))(GDEXTENSION_VARIANT_TYPE_BOOL);
    GDExtensionClassCreationInfo5 info = {0};
    info.is_exposed = 1;
    info.create_instance_func = create_instance;
    info.free_instance_func = free_instance;
    ((GDExtensionInterfaceClassdbRegisterExtensionClass5)api("classdb_register_extension_class5"))(library, &class_name, &base_name, &info);
    GDExtensionPropertyInfo return_info = {0};
    return_info.type = GDEXTENSION_VARIANT_TYPE_BOOL;
    return_info.name = &empty_name;
    return_info.class_name = &empty_name;
    return_info.hint_string = &empty_string;
    GDExtensionClassMethodInfo method = {0};
    method.name = &method_name;
    method.call_func = command;
    method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL | GDEXTENSION_METHOD_FLAG_VARARG;
    method.has_return_value = 1;
    method.return_value_info = &return_info;
    ((GDExtensionInterfaceClassdbRegisterExtensionClassMethod)api("classdb_register_extension_class_method"))(library, &class_name, &method);
}

static void deinitialize(void *data, GDExtensionInitializationLevel level) {
    (void)data;
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    ((GDExtensionInterfaceClassdbUnregisterExtensionClass)api("classdb_unregister_extension_class"))(library, &class_name);
    GDExtensionInterfaceVariantGetPtrDestructor destructor =
        (GDExtensionInterfaceVariantGetPtrDestructor)api("variant_get_ptr_destructor");
    destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(&method_name);
    destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(&base_name);
    destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(&class_name);
    destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(&empty_name);
    destructor(GDEXTENSION_VARIANT_TYPE_STRING)(&empty_string);
}

GDExtensionBool tokenbook_window_init(GDExtensionInterfaceGetProcAddress get_proc,
        GDExtensionClassLibraryPtr lib, GDExtensionInitialization *initialization) {
    api = get_proc;
    library = lib;
    initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
    initialization->initialize = initialize;
    initialization->deinitialize = deinitialize;
    initialization->userdata = NULL;
    return 1;
}
