from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    ASHALoginView, AdminLoginView, load_areas_by_state, StateViewSet, DistrictViewSet,
    AreaViewSet, FamilyViewSet, MemberViewSet, MedicalRecordViewSet, UserViewSet
)

router = DefaultRouter()
router.register(r'states', StateViewSet, basename='state')
router.register(r'districts', DistrictViewSet, basename='district')
router.register(r'areas', AreaViewSet, basename='area')
router.register(r'users', UserViewSet, basename='user')
router.register(r'families', FamilyViewSet, basename='family')
router.register(r'members', MemberViewSet, basename='member')
router.register(r'medical-records', MedicalRecordViewSet, basename='medical-record')

urlpatterns = [
    path('login/', ASHALoginView.as_view(), name='asha-login'),
    path('admin-login/', AdminLoginView.as_view(), name='admin-login'),
    path('ajax/load-areas/', load_areas_by_state, name='ajax_load_areas'),
    path('', include(router.urls)),
]