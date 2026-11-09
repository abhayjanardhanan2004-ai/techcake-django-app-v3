

import os
from django.contrib import admin
from django.urls import path, include
from congrats.views import health

urlpatterns = [
    path("admin/", admin.site.urls),
    path("health", health, name="health"),
    path("", include("congrats.urls")),
]

