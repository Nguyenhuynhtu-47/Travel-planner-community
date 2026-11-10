package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.UserHandleService;
import org.springframework.stereotype.Service;

import java.text.Normalizer;
import java.util.regex.Pattern;

@Service
public class UserHandleServiceImpl implements UserHandleService {

    public static final String HANDLE_REGEX = "^[a-z0-9_.]{3,30}$";
    private static final Pattern HANDLE_PATTERN = Pattern.compile(HANDLE_REGEX);
    private static final Pattern DIACRITICS_PATTERN = Pattern.compile("\\p{InCombiningDiacriticalMarks}+");

    private final UserRepository userRepository;

    public UserHandleServiceImpl(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public String normalize(String handle) {
        if (handle == null) {
            return null;
        }
        String trimmed = handle.trim().toLowerCase();
        if (trimmed.startsWith("@")) {
            trimmed = trimmed.substring(1).trim();
        }
        return trimmed;
    }

    @Override
    public boolean isValidFormat(String handle) {
        if (handle == null) {
            return false;
        }
        return HANDLE_PATTERN.matcher(handle).matches();
    }

    @Override
    public String generateUniqueHandle(String fullName, Integer userId) {
        String base = sanitizeFullNameToBase(fullName);

        // Candidate 1: base or traveler_<userId>
        String candidate;
        if ("traveler".equals(base) && userId != null) {
            candidate = "traveler_" + userId;
        } else {
            candidate = base;
        }

        if (candidate.length() > 30) {
            candidate = candidate.substring(0, 30);
        }

        // If candidate already satisfies uniqueness, return it
        if (!userRepository.existsByHandle(candidate)) {
            return candidate;
        }

        // Candidate 2: base + "_" + userId (if not tried yet)
        if (userId != null && !candidate.equals(base + "_" + userId)) {
            String idSuffix = "_" + userId;
            String trimmedBase = base;
            if (trimmedBase.length() + idSuffix.length() > 30) {
                trimmedBase = trimmedBase.substring(0, 30 - idSuffix.length());
            }
            candidate = trimmedBase + idSuffix;
            if (!userRepository.existsByHandle(candidate)) {
                return candidate;
            }
        }

        // Candidate 3+: Incrementing numeric counter
        int counter = 1;
        while (true) {
            String suffix = "_" + counter;
            String trimmedBase = base;
            if (trimmedBase.length() + suffix.length() > 30) {
                trimmedBase = trimmedBase.substring(0, 30 - suffix.length());
            }
            candidate = trimmedBase + suffix;
            if (!userRepository.existsByHandle(candidate)) {
                return candidate;
            }
            counter++;
        }
    }

    private String sanitizeFullNameToBase(String fullName) {
        if (fullName == null || fullName.isBlank()) {
            return "traveler";
        }

        // Normalize unicode diacritics (e.g. Vietnamese accents)
        String nfd = Normalizer.normalize(fullName.trim(), Normalizer.Form.NFD);
        String withoutAccents = DIACRITICS_PATTERN.matcher(nfd).replaceAll("")
                .replace("đ", "d").replace("Đ", "d");

        // Keep only alphanumeric characters and remove consecutive spaces
        String cleaned = withoutAccents.toLowerCase().replaceAll("[^a-z0-9]", "");

        if (cleaned.length() < 3) {
            return "traveler";
        }

        // Cap base length at 20 characters so suffixes have room
        if (cleaned.length() > 20) {
            return cleaned.substring(0, 20);
        }

        return cleaned;
    }
}

