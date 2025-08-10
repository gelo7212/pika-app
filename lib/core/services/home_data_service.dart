import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/home_data_model.dart';
import '../interfaces/http_client_interface.dart';
// import '../config/api_config.dart'; // Will be used when API is implemented

abstract class HomeDataServiceInterface {
  Future<HomePageData> getHomePageData();
}

class HomeDataService implements HomeDataServiceInterface {
  final HttpClientInterface? client;

  HomeDataService({this.client});

  @override
  Future<HomePageData> getHomePageData() async {
    // TODO: Replace with actual API call when backend is ready
    // For now, load from local JSON file
    return await _loadFromLocalJson();
    
    // Future API implementation:
    // try {
    //   final headers = ApiConfig.getDefaultHeaders();
    //   final url = '${ApiConfig.baseUrl}/home/data';
    //   
    //   final response = await client!.get(url, headers: headers);
    //   
    //   if (response.statusCode == 200) {
    //     final data = response.data;
    //     if (data['success'] == true && data['data'] != null) {
    //       return HomePageData.fromJson(data['data'] as Map<String, dynamic>);
    //     }
    //   }
    //   
    //   throw Exception('Failed to load home page data');
    // } catch (e) {
    //   print('Error fetching home page data: $e');
    //   // Fallback to local data if API fails
    //   return await _loadFromLocalJson();
    // }
  }

  Future<HomePageData> _loadFromLocalJson() async {
    try {
      final String jsonString = await rootBundle.loadString('lib/core/data/home_data.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      return HomePageData.fromJson(jsonData);
    } catch (e) {
      print('Error loading home data from JSON: $e');
      // Return empty data if JSON loading fails
      return const HomePageData(
        categories: [],
        featuredItems: [],
        specialOffers: [],
        advertisements: [],
      );
    }
  }
}
