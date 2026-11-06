
import os
from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse
from django.db import connections
from django.db.utils import OperationalError


def health(request):
    try:
        # Check database connectivity
        connections["default"].cursor()

        return JsonResponse({
            "status": "healthy",
            "sha": os.environ.get("APP_VERSION", "unknown"),
        }, status=200)

    except OperationalError:
        return JsonResponse({
            "status": "unhealthy",
            "sha": os.environ.get("APP_VERSION", "unknown"),
        }, status=503)


urlpatterns = [
    path("admin/", admin.site.urls),
    path("health", health, name="health"),
    path("", include("congrats.urls")),
]

