from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.contrib.auth.forms import UserCreationForm
from .models import User, State, District, Area, Family, Member, MedicalRecord


class CustomUserCreationForm(UserCreationForm):
    class Meta(UserCreationForm.Meta):
        model = User
        fields = ('username', 'first_name', 'last_name', 'phone_number', 'aadhaar_number', 'role', 'state', 'assigned_areas')


class CustomUserAdmin(UserAdmin):
    model = User
    add_form = CustomUserCreationForm

    list_display = ['username', 'first_name', 'last_name', 'phone_number', 'aadhaar_number', 'state', 'get_assigned_areas', 'role', 'is_staff']
    
    def get_assigned_areas(self, obj):
        return ", ".join([a.village_or_ward for a in obj.assigned_areas.all()])
    get_assigned_areas.short_description = 'Assigned Areas'
    list_filter = ['role', 'state', 'is_staff']
    search_fields = ['username', 'first_name', 'last_name', 'phone_number', 'aadhaar_number']

    fieldsets = UserAdmin.fieldsets + (
        ('ASHA Details & Location', {'fields': ('role', 'phone_number', 'aadhaar_number', 'state', 'assigned_areas')}),
    )

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('username', 'first_name', 'last_name', 'role', 'phone_number', 'aadhaar_number', 'state', 'assigned_areas'),
        }),
    )

    class Media:
        js = ('admin/js/dependent_dropdown.js',)


admin.site.register(User, CustomUserAdmin)
admin.site.register(State)
admin.site.register(District)
admin.site.register(Area)
admin.site.register(Family)
admin.site.register(Member)
admin.site.register(MedicalRecord)