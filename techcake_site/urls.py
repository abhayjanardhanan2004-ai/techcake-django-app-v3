
import os
from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse


def health(request):
    return JsonResponse({
        "status": "healthy",
        "sha": os.environ.get("APP_VERSION", "unknown"),
    })


urlpatterns = [
    path("admin/", admin.site.urls),
    path("health", health, name="health"),
    path("", include("congrats.urls")),
]
