cmake_minimum_required(VERSION 3.14)
project(awesome_safe LANGUAGES CXX)
set(BINARY_NAME "awesome_safe")
set(APPLICATION_ID "com.awesome.safe")
add_subdirectory("flutter")
add_subdirectory("runner")

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/resources/app_icon.png"
	DESTINATION "${CMAKE_INSTALL_PREFIX}/data"
	COMPONENT Runtime)
