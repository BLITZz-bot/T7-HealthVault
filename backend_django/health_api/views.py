from rest_framework import viewsets, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from django.http import JsonResponse
from .models import User, State, District, Area, Family, Member, MedicalRecord
from .serializers import (
    ASHALoginSerializer, StateSerializer, DistrictSerializer, AreaSerializer,
    FamilySerializer, MemberSerializer, MedicalRecordSerializer, UserSerializer
)


def load_areas_by_state(request):
    state_id = request.GET.get('state_id')
    areas = Area.objects.filter(state_id=state_id).order_by('village_or_ward')
    data = [{'id': str(area.id), 'name': f"{area.village_or_ward} ({area.district}, {area.block})"} for area in areas]
    return JsonResponse(data, safe=False)


class ASHALoginView(APIView):
    permission_classes = []  # Public endpoint for login

    def post(self, request):
        serializer = ASHALoginSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.validated_data['user']

            # Generate JWT Tokens
            refresh = RefreshToken.for_user(user)

            return Response({
                'message': 'Login successful',
                'tokens': {
                    'refresh': str(refresh),
                    'access': str(refresh.access_token),
                },
                'user': UserSerializer(user).data
            }, status=status.HTTP_200_OK)

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AdminLoginView(APIView):
    permission_classes = []

    def post(self, request):
        username = request.data.get('username', '').strip()
        password = request.data.get('password', '').strip()

        user = User.objects.filter(username__iexact=username).first()

        if user and user.check_password(password):
            if user.is_superuser or user.is_staff or user.role == 'admin':
                refresh = RefreshToken.for_user(user)
                return Response({
                    'message': 'Admin login successful',
                    'tokens': {
                        'refresh': str(refresh),
                        'access': str(refresh.access_token),
                    },
                    'user': {
                        'id': str(user.id) if hasattr(user, 'id') else user.pk,
                        'username': user.username,
                        'role': user.role,
                    }
                }, status=status.HTTP_200_OK)

        return Response({'error': 'Invalid Admin Username or Password'}, status=status.HTTP_400_BAD_REQUEST)


class StateViewSet(viewsets.ModelViewSet):
    queryset = State.objects.all()
    serializer_class = StateSerializer
    permission_classes = [permissions.IsAuthenticated]


class DistrictViewSet(viewsets.ModelViewSet):
    queryset = District.objects.all()
    serializer_class = DistrictSerializer
    permission_classes = [permissions.IsAuthenticated]


class AreaViewSet(viewsets.ModelViewSet):
    queryset = Area.objects.all()
    serializer_class = AreaSerializer
    permission_classes = [permissions.IsAuthenticated]


class FamilyViewSet(viewsets.ModelViewSet):
    serializer_class = FamilySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'asha' and user.assigned_areas.exists():
            # Scoped to only families in the ASHA worker's assigned area
            return Family.objects.filter(area__in=user.assigned_areas.all(), is_deleted=False)
        return Family.objects.filter(is_deleted=False)

    def perform_create(self, serializer):
        user = self.request.user
        if user.role == 'asha' and user.assigned_areas.exists():
            if 'area' not in serializer.validated_data:
                serializer.save(area=user.assigned_areas.first())
            else:
                serializer.save()
        else:
            serializer.save()


class MemberViewSet(viewsets.ModelViewSet):
    serializer_class = MemberSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'asha' and user.assigned_areas.exists():
            # Scoped to members in families within the ASHA worker's assigned area
            return Member.objects.filter(family__area__in=user.assigned_areas.all(), is_deleted=False)
        return Member.objects.filter(is_deleted=False)


class UserViewSet(viewsets.ModelViewSet):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return User.objects.filter(role='asha')

    def perform_create(self, serializer):
        serializer.save(role='asha')


class MedicalRecordViewSet(viewsets.ModelViewSet):
    serializer_class = MedicalRecordSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'asha' and user.assigned_areas.exists():
            return MedicalRecord.objects.filter(member__family__area__in=user.assigned_areas.all(), is_deleted=False)
        return MedicalRecord.objects.filter(is_deleted=False)

    def perform_create(self, serializer):
        serializer.save(recorded_by=self.request.user)