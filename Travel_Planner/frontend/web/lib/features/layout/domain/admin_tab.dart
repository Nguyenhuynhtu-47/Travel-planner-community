import 'package:flutter/material.dart';

enum AdminTabGroup {
  overview('TỔNG QUAN'),
  community('QUẢN LÝ CỘNG ĐỒNG'),
  travel('QUẢN LÝ DU LỊCH'),
  content('QUẢN LÝ NỘI DUNG'),
  system('HỆ THỐNG');

  final String label;
  const AdminTabGroup(this.label);
}

enum AdminTab {
  dashboard,
  posts,
  reports,
  users,
  places,
  itineraries,
  media,
  administrativeAreas,
  auditLogs,
  settings,
  profile;

  String get title {
    switch (this) {
      case AdminTab.dashboard:
        return 'Tổng quan';
      case AdminTab.posts:
        return 'Kiểm duyệt bài viết';
      case AdminTab.reports:
        return 'Quản lý báo cáo';
      case AdminTab.users:
        return 'Quản lý người dùng';
      case AdminTab.places:
        return 'Quản lý Địa điểm Chuẩn hóa (Places)';
      case AdminTab.itineraries:
        return 'Quản lý lịch trình';
      case AdminTab.media:
        return 'Quản lý tài nguyên đa phương tiện';
      case AdminTab.administrativeAreas:
        return 'Quản lý khu vực hành chính';
      case AdminTab.auditLogs:
        return 'Nhật ký hoạt động';
      case AdminTab.settings:
        return 'Cài đặt hệ thống';
      case AdminTab.profile:
        return 'Hồ sơ cá nhân';
    }
  }

  String get shortTitle {
    switch (this) {
      case AdminTab.dashboard:
        return 'Tổng quan';
      case AdminTab.posts:
        return 'Kiểm duyệt bài viết';
      case AdminTab.reports:
        return 'Quản lý báo cáo';
      case AdminTab.users:
        return 'Quản lý người dùng';
      case AdminTab.places:
        return 'Quản lý địa điểm';
      case AdminTab.itineraries:
        return 'Quản lý lịch trình';
      case AdminTab.media:
        return 'Quản lý hình ảnh';
      case AdminTab.administrativeAreas:
        return 'Khu vực hành chính';
      case AdminTab.auditLogs:
        return 'Nhật ký hoạt động';
      case AdminTab.settings:
        return 'Cài đặt';
      case AdminTab.profile:
        return 'Hồ sơ';
    }
  }

  AdminTabGroup get group {
    switch (this) {
      case AdminTab.dashboard:
        return AdminTabGroup.overview;
      case AdminTab.posts:
      case AdminTab.reports:
      case AdminTab.users:
        return AdminTabGroup.community;
      case AdminTab.places:
      case AdminTab.itineraries:
        return AdminTabGroup.travel;
      case AdminTab.media:
      case AdminTab.administrativeAreas:
        return AdminTabGroup.content;
      case AdminTab.auditLogs:
      case AdminTab.settings:
      case AdminTab.profile:
        return AdminTabGroup.system;
    }
  }

  IconData get icon {
    switch (this) {
      case AdminTab.dashboard:
        return Icons.dashboard_outlined;
      case AdminTab.posts:
        return Icons.article_outlined;
      case AdminTab.reports:
        return Icons.report_problem_outlined;
      case AdminTab.users:
        return Icons.people_outline;
      case AdminTab.places:
        return Icons.place_outlined;
      case AdminTab.itineraries:
        return Icons.map_outlined;
      case AdminTab.media:
        return Icons.perm_media_outlined;
      case AdminTab.administrativeAreas:
        return Icons.location_city_outlined;
      case AdminTab.auditLogs:
        return Icons.receipt_long_outlined;
      case AdminTab.settings:
        return Icons.settings_outlined;
      case AdminTab.profile:
        return Icons.person_outline;
    }
  }

  IconData get activeIcon {
    switch (this) {
      case AdminTab.dashboard:
        return Icons.dashboard;
      case AdminTab.posts:
        return Icons.article;
      case AdminTab.reports:
        return Icons.report_problem;
      case AdminTab.users:
        return Icons.people;
      case AdminTab.places:
        return Icons.place;
      case AdminTab.itineraries:
        return Icons.map;
      case AdminTab.media:
        return Icons.perm_media;
      case AdminTab.administrativeAreas:
        return Icons.location_city;
      case AdminTab.auditLogs:
        return Icons.receipt_long;
      case AdminTab.settings:
        return Icons.settings;
      case AdminTab.profile:
        return Icons.person;
    }
  }

  bool get isImplemented {
    switch (this) {
      case AdminTab.dashboard:
      case AdminTab.posts:
      case AdminTab.reports:
      case AdminTab.users:
      case AdminTab.places:
      case AdminTab.itineraries:
      case AdminTab.media:
      case AdminTab.administrativeAreas:
      case AdminTab.auditLogs:
      case AdminTab.settings:
      case AdminTab.profile:
        return true;
    }
  }

  String get routePath {
    switch (this) {
      case AdminTab.dashboard:
        return '/dashboard';
      case AdminTab.posts:
        return '/posts';
      case AdminTab.reports:
        return '/reports';
      case AdminTab.users:
        return '/users';
      case AdminTab.places:
        return '/places';
      case AdminTab.itineraries:
        return '/itineraries';
      case AdminTab.media:
        return '/media';
      case AdminTab.administrativeAreas:
        return '/administrative-areas';
      case AdminTab.auditLogs:
        return '/audit-logs';
      case AdminTab.settings:
        return '/settings';
      case AdminTab.profile:
        return '/profile';
    }
  }

  static AdminTab fromRoute(String? rawRoute) {
    if (rawRoute == null || rawRoute.isEmpty || rawRoute == '/') {
      return AdminTab.dashboard;
    }
    final clean = rawRoute
        .toLowerCase()
        .replaceAll('#', '')
        .replaceAll('/', '')
        .trim();
    for (final tab in AdminTab.values) {
      if (tab.name.toLowerCase() == clean) return tab;
      if (tab.routePath.replaceAll('/', '').toLowerCase() == clean) return tab;
    }
    if (clean.contains('post')) return AdminTab.posts;
    if (clean.contains('report')) return AdminTab.reports;
    if (clean.contains('place')) return AdminTab.places;
    if (clean.contains('media')) return AdminTab.media;
    if (clean.contains('user')) return AdminTab.users;
    if (clean.contains('itinerar')) return AdminTab.itineraries;
    if (clean.contains('area') || clean.contains('admin')) {
      return AdminTab.administrativeAreas;
    }
    if (clean.contains('audit') || clean.contains('log')) {
      return AdminTab.auditLogs;
    }
    if (clean.contains('setting')) return AdminTab.settings;
    if (clean.contains('profile')) return AdminTab.profile;
    return AdminTab.dashboard;
  }
}
