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
        return 'Tổng quan Dashboard';
      case AdminTab.posts:
        return 'Kiểm duyệt bài viết';
      case AdminTab.reports:
        return 'Quản lý báo cáo';
      case AdminTab.users:
        return 'Quản lý người dùng';
      case AdminTab.places:
        return 'Quản lý địa điểm chuẩn hóa';
      case AdminTab.itineraries:
        return 'Quản lý lịch trình';
      case AdminTab.media:
        return 'Quản lý Media Assets';
      case AdminTab.administrativeAreas:
        return 'Quản lý khu vực hành chính';
      case AdminTab.auditLogs:
        return 'Nhật ký hoạt động (Audit Logs)';
      case AdminTab.settings:
        return 'Cài đặt hệ thống';
      case AdminTab.profile:
        return 'Hồ sơ cá nhân';
    }
  }

  String get shortTitle {
    switch (this) {
      case AdminTab.dashboard:
        return 'Dashboard';
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
        return 'Quản lý Media';
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
      case AdminTab.places:
      case AdminTab.media:
      case AdminTab.profile:
        return true;
      case AdminTab.users:
      case AdminTab.itineraries:
      case AdminTab.administrativeAreas:
      case AdminTab.auditLogs:
      case AdminTab.settings:
        return false;
    }
  }
}
