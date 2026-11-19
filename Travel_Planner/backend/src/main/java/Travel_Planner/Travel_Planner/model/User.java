package Travel_Planner.Travel_Planner.model;

import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import jakarta.persistence.*;
import lombok.*;

import java.text.Normalizer;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "users")
@Getter
@Setter
@Builder
public class User {

    public User() {
    }

    public User(Integer userId, String username, String password, String email, Role role,
                UserStatus status, String avatar, String fullName, String phone, String address,
                String bio, LocalDateTime createdAt, LocalDateTime updatedAt) {
        this(userId, username, null, password, email, role, status, avatar, fullName, phone, address, bio, createdAt, updatedAt);
    }

    public User(Integer userId, String username, String handle, String password, String email, Role role,
                UserStatus status, String avatar, String fullName, String phone, String address,
                String bio, LocalDateTime createdAt, LocalDateTime updatedAt) {
        this(userId, username, handle, password, email, false, role, status, 1, avatar, fullName, phone, address, bio, createdAt, updatedAt);
    }

    public User(Integer userId, String username, String handle, String password, String email, Boolean emailVerified,
                Role role, UserStatus status, Integer tokenVersion, String avatar, String fullName, String phone,
                String address, String bio, LocalDateTime createdAt, LocalDateTime updatedAt) {
        this.userId = userId;
        this.username = username;
        this.handle = handle;
        this.password = password;
        this.email = email;
        this.emailVerified = emailVerified != null ? emailVerified : false;
        this.role = role;
        this.status = status;
        this.tokenVersion = tokenVersion != null ? tokenVersion : 1;
        this.avatar = avatar;
        this.fullName = fullName;
        this.phone = phone;
        this.address = address;
        this.bio = bio;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "user_id")
    private Integer userId;

    @Column(name = "username", nullable = false, unique = true, length = 50)
    private String username;

    @Column(name = "handle", nullable = false, unique = true, length = 30)
    private String handle;

    @Column(name = "password", nullable = false, length = 255)
    private String password;

    @Column(name = "email", nullable = false, unique = true, length = 100)
    private String email;

    @Column(name = "email_verified", nullable = false)
    @Builder.Default
    private Boolean emailVerified = false;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false, length = 20)
    @Builder.Default
    private Role role = Role.USER;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    @Builder.Default
    private UserStatus status = UserStatus.ACTIVE;

    @Column(name = "token_version", nullable = false)
    @Builder.Default
    private Integer tokenVersion = 1;

    @Column(name = "avatar", length = 500)
    private String avatar;

    @Column(name = "full_name", length = 100)
    private String fullName;

    @Column(name = "phone", length = 20)
    private String phone;

    @Column(name = "address", length = 255)
    private String address;

    @Column(name = "bio", columnDefinition = "TEXT")
    private String bio;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
        if (this.role == null) {
            this.role = Role.USER;
        }
        if (this.status == null) {
            this.status = UserStatus.ACTIVE;
        }
        if (this.emailVerified == null) {
            this.emailVerified = false;
        }
        if (this.tokenVersion == null) {
            this.tokenVersion = 1;
        }
        if (this.handle == null || this.handle.trim().isEmpty()) {
            String base = "traveler";
            if (this.fullName != null && !this.fullName.trim().isEmpty()) {
                String normalized = Normalizer.normalize(this.fullName.trim(), Normalizer.Form.NFD)
                        .replaceAll("\\p{M}", "")
                        .replace('đ', 'd')
                        .replace('Đ', 'd')
                        .toLowerCase()
                        .replaceAll("[^a-z0-9_.]", "");
                if (normalized.length() >= 3) {
                    base = normalized.length() > 20 ? normalized.substring(0, 20) : normalized;
                }
            }
            this.handle = base + "_" + UUID.randomUUID().toString().replace("-", "").substring(0, 6);
        } else {
            this.handle = this.handle.trim().toLowerCase();
        }
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
        if (this.handle != null) {
            this.handle = this.handle.trim().toLowerCase();
        }
    }
}
