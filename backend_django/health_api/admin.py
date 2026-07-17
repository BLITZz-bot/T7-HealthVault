from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User, Area, Family, Member, MedicalRecord

class CustomUserAdmin(UserAdmin):
    model = User
    list_display = ['username', 'email', 'role', 'is_staff']
    fieldsets = UserAdmin.fieldsets + (
        (None, {'fields': ('role', 'phone_number')}),
    )
    add_fieldsets = UserAdmin.add_fieldsets + (
        (None, {'fields': ('role', 'phone_number')}),
    )

admin.site.register(User, CustomUserAdmin)
admin.site.register(Area)
admin.site.register(Family)
admin.site.register(Member)
admin.site.register(MedicalRecord)