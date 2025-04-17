import 'package:taxi_driver/model/CurrentRequestModel.dart';
import 'package:taxi_driver/model/PaginationModel.dart';

import 'RiderModel.dart';

class RideRequestList {
  List<OnRideRequest>? data;
  PaginationModel? pagination;

  RideRequestList({this.data, this.pagination});

  factory RideRequestList.fromJson(Map<String, dynamic> json) {
    return RideRequestList(
      data: json['data'] != null ? (json['data'] as List).map((i) => OnRideRequest.fromJson(i)).toList() : null,
      pagination: json['pagination'] != null ? PaginationModel.fromJson(json['pagination']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    if (this.pagination != null) {
      data['pagination'] = this.pagination!.toJson();
    }
    return data;
  }
}
