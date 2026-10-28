cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)
add_executable(${BINARY_NAME} WIN32
	"flutter_window.cpp"
	"main.cpp"
	"utils.cpp"
	"win32_window.cpp"
	"${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
	"Runner.rc"
	"runner.exe.manifest"
)
apply_standard_settings(${BINARY_NAME})
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
add_dependencies(${BINARY_NAME} flutter_assemble)
add_custom_command(
	TARGET ${BINARY_NAME} POST_BUILD
	COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:${BINARY_NAME}>/data"
	COMMAND ${CMAKE_COMMAND} -E copy_directory
		"${PROJECT_BUILD_DIR}/flutter_assets"
		"$<TARGET_FILE_DIR:${BINARY_NAME}>/data/flutter_assets"
	COMMENT "Copiando automaticamente flutter_assets para o bundle"
)
