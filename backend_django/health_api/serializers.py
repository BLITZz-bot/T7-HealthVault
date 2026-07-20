from rest_framework import serializers
from .models import User, State, District, Area, Family, Member, MedicalRecord

class ASHALoginSerializer(serializers.Serializer):
    name = serializers.CharField(required=True)
    phone_number = serializers.CharField(required=True)

    def validate(self, data):
        name = data.get('name').strip()
        phone_number = data.get('phone_number').strip()

        # Find ASHA worker matching phone_number and name (username or first_name)
        user = User.objects.filter(
            phone_number=phone_number,
            role='asha'
        ).filter(
            username__iexact=name
        ).first()

        if not user:
            # Fallback check for first_name
            user = User.objects.filter(
                phone_number=phone_number,
                first_name__iexact=name,
                role='asha'
            ).first()

        if not user:
            raise serializers.ValidationError("Invalid Name or Phone Number. Please check with your Admin.")

        data['user'] = user
        return data


class StateSerializer(serializers.ModelSerializer):
    class Meta:
        model = State
        fields = '__all__'


class DistrictSerializer(serializers.ModelSerializer):
    state_name = serializers.CharField(source='state.name', read_only=True)

    class Meta:
        model = District
        fields = '__all__'


class AreaSerializer(serializers.ModelSerializer):
    district_name = serializers.CharField(source='district.name', read_only=True)
    state = serializers.UUIDField(source='district.state.id', read_only=True)
    state_name = serializers.CharField(source='district.state.name', read_only=True)

    class Meta:
        model = Area
        fields = '__all__'


class FamilySerializer(serializers.ModelSerializer):
    area_detail = AreaSerializer(source='area', read_only=True)

    class Meta:
        model = Family
        fields = '__all__'


class MemberSerializer(serializers.ModelSerializer):
    class Meta:
        model = Member
        fields = '__all__'


class UserSerializer(serializers.ModelSerializer):
    state_name = serializers.CharField(source='state.name', read_only=True)
    area_names = serializers.SerializerMethodField()

    def get_area_names(self, obj):
        return [f"{a.village_or_ward} ({a.district})" for a in obj.assigned_areas.all()]
    password = serializers.CharField(write_only=True, required=False, allow_blank=True)

    class Meta:
        model = User
        fields = ['id', 'username', 'first_name', 'last_name', 'phone_number', 'aadhaar_number',
                  'role', 'state', 'state_name', 'assigned_areas', 'area_names',
                  'is_active', 'password']

    def create(self, validated_data):
        password = validated_data.pop('password', None)
        user = super().create(validated_data)
        if password:
            user.set_password(password)
        else:
            # Set unusable password so login still works via phone+name
            user.set_unusable_password()
        user.save()
        return user


class MedicalRecordSerializer(serializers.ModelSerializer):
    recorded_by_name = serializers.CharField(source='recorded_by.username', read_only=True)

    class Meta:
        model = MedicalRecord
        fields = '__all__'