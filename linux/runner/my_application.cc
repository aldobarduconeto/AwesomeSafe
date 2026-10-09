#include "my_application.h"
#include <flutter_linux/flutter_linux.h>

struct _MyApplication { GtkApplication parent_instance; FlView* view; };
G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)
static void my_application_activate(GApplication* application) {
  auto* self = MY_APPLICATION(application);
  auto* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  gtk_window_set_default_size(window, 900, 650);
  gtk_window_set_icon_from_file(window, "data/app_icon.png", nullptr);
  self->view = fl_view_new(GTK_WINDOW(window));
  gtk_widget_show(GTK_WIDGET(window));
}
static void my_application_class_init(MyApplicationClass* klass) { G_APPLICATION_CLASS(klass)->activate = my_application_activate; }
static void my_application_init(MyApplication*) {}
MyApplication* my_application_new() { return MY_APPLICATION(g_object_new(my_application_get_type(), "application-id", "com.awesome.safe", nullptr)); }
