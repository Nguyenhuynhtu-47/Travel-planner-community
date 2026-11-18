package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.ChangePasswordRequest;
import Travel_Planner.Travel_Planner.dto.request.LoginRequest;
import Travel_Planner.Travel_Planner.dto.request.RegisterRequest;
import Travel_Planner.Travel_Planner.dto.response.AuthResponse;
import Travel_Planner.Travel_Planner.dto.response.ChangePasswordResponse;
import Travel_Planner.Travel_Planner.dto.response.RegisterResponse;
import Travel_Planner.Travel_Planner.dto.response.UserResponse;

public interface AuthService {

    RegisterResponse register(RegisterRequest request);

    AuthResponse login(LoginRequest request);

    AuthResponse login(LoginRequest request, String deviceInfo, String ipAddress);

    UserResponse getCurrentUser(String username);

    ChangePasswordResponse changePassword(String username, ChangePasswordRequest request);
}
