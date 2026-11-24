cmake_minimum_required(VERSION 3.22.1)
project("suoxia_jni")

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../core/rust/include)

add_library(securevault_core SHARED IMPORTED)
set_target_properties(securevault_core PROPERTIES
    IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libsecurevault_core.so
)

add_library(suoxia_jni SHARED sv_jni.c)
find_library(log-lib log)
target_link_libraries(suoxia_jni ${log-lib} securevault_core)
