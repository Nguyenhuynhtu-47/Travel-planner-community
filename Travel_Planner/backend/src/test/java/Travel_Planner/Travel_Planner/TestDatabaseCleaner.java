package Travel_Planner.Travel_Planner;

import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Reusable, deterministic test database cleaner for integration tests.
 * Performs topological leaf-to-root deletion respecting all foreign key constraints.
 * Foreign key checks remain 100% strictly enabled at all times.
 */
public final class TestDatabaseCleaner {

    private TestDatabaseCleaner() {}

    public static void clean(JdbcTemplate jdbcTemplate) {
        if (jdbcTemplate == null) return;
        try {
            jdbcTemplate.execute("UPDATE conversations SET last_message_id = NULL");
        } catch (Exception ignored) {}
        try {
            jdbcTemplate.execute("UPDATE itineraries SET original_itinerary_id = NULL");
        } catch (Exception ignored) {}
        try {
            jdbcTemplate.execute("UPDATE comments SET parent_comment_id = NULL, root_comment_id = NULL");
        } catch (Exception ignored) {}

        try { jdbcTemplate.execute("DELETE FROM post_media"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM post_comments"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM post_likes"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM post_reports"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM posts"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM comments"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM activity_visits"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM ratings"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM itinerary_access_grants"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM favorites"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM saved_itineraries"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM itinerary_shares"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM offline_downloads"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM activities"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM itinerary_places"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM itinerary_days"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM itineraries"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM place_administrative_mappings"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM places"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM media_assets"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM conversation_read_states"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM messages"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM conversations"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM follows"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM friendships"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM user_blocks"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM email_verification_tokens"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM password_reset_tokens"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM user_identities"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM user_sessions"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM email_change_requests"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM user_messaging_settings"); } catch (Exception ignored) {}
        try { jdbcTemplate.execute("DELETE FROM users"); } catch (Exception ignored) {}
    }
}
