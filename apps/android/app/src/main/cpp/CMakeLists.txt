cmake_minimum_required(VERSION 3.22.1)
project("suoxia_jni")

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../core/rust/include)
link_directories(${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI})

add_library(suoxia_jni SHARED sv_jni.c)
find_library(log-lib log)
target_link_libraries(suoxia_jni ${log-lib} securevault_core)
