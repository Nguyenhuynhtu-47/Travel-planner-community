package Travel_Planner.Travel_Planner.model;

import Travel_Planner.Travel_Planner.model.enums.InboundMessagePolicy;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.time.LocalDateTime;

@Entity
@Table(name = "user_messaging_settings")
@Getter @Setter @NoArgsConstructor
public class UserMessagingSettings {
    @Id
    @Column(name = "user_id")
    private Integer userId;

    @MapsId
    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "inbound_policy", nullable = false, length = 20)
    private InboundMessagePolicy inboundPolicy = InboundMessagePolicy.FRIENDS_ONLY;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    public UserMessagingSettings(User user) {
        this.user = user;
        this.userId = user.getUserId();
        this.inboundPolicy = InboundMessagePolicy.FRIENDS_ONLY;
    }

    @PrePersist @PreUpdate
    protected void onSave() { updatedAt = LocalDateTime.now(); }
}
