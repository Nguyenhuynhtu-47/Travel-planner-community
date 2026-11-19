package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.ForgotPasswordRequest;
import Travel_Planner.Travel_Planner.dto.request.ResetPasswordRequest;
import Travel_Planner.Travel_Planner.dto.request.VerifyResetOtpRequest;
import Travel_Planner.Travel_Planner.dto.response.ForgotPasswordResponse;
import Travel_Planner.Travel_Planner.dto.response.ResetPasswordResponse;
import Travel_Planner.Travel_Planner.dto.response.VerifyResetOtpResponse;

public interface PasswordResetService {

    ForgotPasswordResponse forgotPassword(ForgotPasswordRequest request);

    VerifyResetOtpResponse verifyResetOtp(VerifyResetOtpRequest request);

    ResetPasswordResponse resetPassword(ResetPasswordRequest request);
}
