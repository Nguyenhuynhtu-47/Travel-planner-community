import 'post_model.dart';

class PostCommentModel {
  final int commentId;
  final int postId;
  final String content;
  final PostAuthorModel author;
  final bool isOwner;
  final int? parentCommentId;
  final int? rootCommentId;
  final PostAuthorModel? replyToUser;
  final int replyCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PostCommentModel({
    required this.commentId,
    required this.postId,
    required this.content,
    required this.author,
    this.isOwner = false,
    this.parentCommentId,
    this.rootCommentId,
    this.replyToUser,
    this.replyCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory PostCommentModel.fromJson(Map<String, dynamic> json) {
    return PostCommentModel(
      commentId: json['commentId'] is int
          ? json['commentId'] as int
          : int.tryParse('${json['commentId']}') ?? 0,
      postId: json['postId'] is int
          ? json['postId'] as int
          : int.tryParse('${json['postId']}') ?? 0,
      content: json['content']?.toString() ?? '',
      author: PostAuthorModel.fromJson(
          Map<String, dynamic>.from(json['author'] as Map? ?? {})),
      isOwner: json['isOwner'] == true,
      parentCommentId: json['parentCommentId'] is int
          ? json['parentCommentId'] as int
          : int.tryParse('${json['parentCommentId']}'),
      rootCommentId: json['rootCommentId'] is int
          ? json['rootCommentId'] as int
          : int.tryParse('${json['rootCommentId']}'),
      replyToUser: json['replyToUser'] != null
          ? PostAuthorModel.fromJson(
              Map<String, dynamic>.from(json['replyToUser'] as Map? ?? {}))
          : null,
      replyCount: json['replyCount'] is int
          ? json['replyCount'] as int
          : int.tryParse('${json['replyCount']}') ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'commentId': commentId,
    'postId': postId,
    'content': content,
    'author': author.toJson(),
    'isOwner': isOwner,
    'parentCommentId': parentCommentId,
    'rootCommentId': rootCommentId,
    'replyToUser': replyToUser?.toJson(),
    'replyCount': replyCount,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
}

