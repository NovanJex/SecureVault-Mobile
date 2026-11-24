cmake_minimum_required(VERSION 3.5.0)
project(suoxia_napi)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})
include_directories(
    ${NATIVERENDER_ROOT_PATH}
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../core/rust/include
)

add_library(securevault_core SHARED IMPORTED)
set_target_properties(securevault_core PROPERTIES
    IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/../../../libs/${OHOS_ARCH}/libsecurevault_core.so
)

add_library(suoxia_napi SHARED napi_init.cpp)
target_link_libraries(suoxia_napi PUBLIC libace_napi.z.so securevault_core)
