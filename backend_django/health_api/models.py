from django.db import models
from django.contrib.auth.models import AbstractUser
import uuid

class State(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100, unique=True)

    def __str__(self):
        return self.name

class District(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    state = models.ForeignKey(State, on_delete=models.CASCADE, related_name='districts')
    name = models.CharField(max_length=100)

    def __str__(self):
        return f"{self.name} ({self.state.name})"

class Area(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    district = models.ForeignKey(District, on_delete=models.CASCADE, related_name='areas', null=True, blank=True)
    block = models.CharField(max_length=100)
    village_or_ward = models.CharField(max_length=100)

    def __str__(self):
        return f"{self.village_or_ward} ({self.district.name}, {self.district.state.name})"

class User(AbstractUser):
    ROLE_CHOICES = (
        ('admin', 'Admin'),
        ('asha', 'ASHA Worker'),
    )
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='asha')
    phone_number = models.CharField(max_length=15, blank=True, null=True)
    aadhaar_number = models.CharField(max_length=12, unique=True, blank=True, null=True, help_text="12-digit Aadhaar Number")
    state = models.ForeignKey(                                                                
            'State',                                                                              
            on_delete=models.SET_NULL,                                                            
            null=True,                                                                            
            blank=True,                                                                           
            related_name='state_users'                                                            
        )
    assigned_areas = models.ManyToManyField(
        Area,
        blank=True,
        related_name='asha_workers',
        help_text="Select multiple assigned areas"
    )

    def __str__(self):
        return f"{self.username} ({self.get_role_display()})"


class Family(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    area = models.ForeignKey(Area, on_delete=models.CASCADE, related_name='families')
    family_head_name = models.CharField(max_length=200)
    house_number = models.CharField(max_length=50)
    contact_number = models.CharField(max_length=15, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_deleted = models.BooleanField(default=False)

    def __str__(self):
        return f"Family of {self.family_head_name} - House {self.house_number}"


class Member(models.Model):
    GENDER_CHOICES = (
        ('male', 'Male'),
        ('female', 'Female'),
        ('other', 'Other'),
    )
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    family = models.ForeignKey(Family, on_delete=models.CASCADE, related_name='members')
    full_name = models.CharField(max_length=200)
    age = models.IntegerField()
    gender = models.CharField(max_length=10, choices=GENDER_CHOICES)
    relationship_to_head = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_deleted = models.BooleanField(default=False)

    def __str__(self):
        return self.full_name


class MedicalRecord(models.Model):
    ENTRY_SOURCE_CHOICES = (
        ('manual', 'Manual Entry'),
        ('device', 'Device Reading'),
    )
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='medical_records')
    blood_sugar_fasting = models.FloatField(null=True, blank=True, help_text="mg/dL")
    blood_sugar_postprandial = models.FloatField(null=True, blank=True, help_text="mg/dL")
    blood_pressure_systolic = models.IntegerField(null=True, blank=True)
    blood_pressure_diastolic = models.IntegerField(null=True, blank=True)
    temperature = models.FloatField(null=True, blank=True, help_text="Fahrenheit")
    pulse_rate = models.IntegerField(null=True, blank=True)
    notes = models.TextField(blank=True, null=True)
    entry_source = models.CharField(max_length=10, choices=ENTRY_SOURCE_CHOICES, default='manual')
    device_id = models.CharField(max_length=100, blank=True, null=True, help_text="Device identifier for device-sourced readings")
    recorded_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='recorded_visits')
    recorded_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_deleted = models.BooleanField(default=False)

    def __str__(self):
        return f"Health Record for {self.member.full_name} on {self.recorded_at.strftime('%Y-%m-%d')}"