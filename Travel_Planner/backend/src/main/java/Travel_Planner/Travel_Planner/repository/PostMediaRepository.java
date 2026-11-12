package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.PostMedia;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface PostMediaRepository extends JpaRepository<PostMedia, Long> {

    List<PostMedia> findByPost_PostIdOrderByDisplayOrderAsc(Long postId);

    @Query("SELECT pm FROM PostMedia pm JOIN FETCH pm.mediaAsset ma WHERE pm.post.postId IN :postIds ORDER BY pm.post.postId ASC, pm.displayOrder ASC")
    List<PostMedia> findByPostIdsWithAsset(@Param("postIds") List<Long> postIds);

    boolean existsByMediaAsset_MediaAssetId(Long mediaAssetId);

    void deleteByPost_PostId(Long postId);
}

