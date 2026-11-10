package Travel_Planner.Travel_Planner.service;

public interface UserHandleService {

    /**
     * Normalizes a handle (trims whitespace, converts to lowercase).
     */
    String normalize(String handle);

    /**
     * Checks if a handle satisfies the allowed format and length:
     * 3 to 30 characters, lowercase letters (a-z), digits (0-9), dots (.), underscores (_).
     */
    boolean isValidFormat(String handle);

    /**
     * Generates a unique, non-null handle derived solely from the user's full name and/or userId.
     * This method MUST NEVER derive the handle from the user's private login username.
     *
     * @param fullName the user's full name (can be null or blank)
     * @param userId the user's ID (can be null for new unpersisted users)
     * @return a unique, valid handle guaranteed not to collide with existing users
     */
    String generateUniqueHandle(String fullName, Integer userId);
}

