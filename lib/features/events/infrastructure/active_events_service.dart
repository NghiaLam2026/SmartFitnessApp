import 'package:dio/dio.dart';
import 'package:smart_fitness_app/core/constants/app_constants.dart';
import 'package:smart_fitness_app/features/events/domain/event_model.dart';

/// Service for fetching events from Active.com API through backend
class ActiveEventsService {
  final Dio _dio;
  final String baseUrl;

  ActiveEventsService({String? baseUrl, Dio? dio})
      : baseUrl = baseUrl ?? AppConstants.aiWorkoutBackendUrl,
        _dio = dio ?? Dio(BaseOptions(
          baseUrl: baseUrl ?? AppConstants.aiWorkoutBackendUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

  /// Search for events by zipcode
  Future<ActiveEventsResponse> searchNearbyEvents({
    required String zip,
    String? query,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      print('🚀 ActiveEventsService: Searching events for zipcode: $zip');
      
      final queryParams = <String, dynamic>{
        'zip': zip,
        'page': page.toString(),
        'perPage': perPage.toString(),
      };

      if (query != null && query.isNotEmpty) {
        queryParams['query'] = query;
        print('🔍 Query: $query');
      }
      if (startDate != null) {
        queryParams['startDate'] = startDate;
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate;
      }

      print('📡 Calling backend: /api/events/nearby with params: $queryParams');
      
      final response = await _dio.get(
        '/api/events/nearby',
        queryParameters: queryParams,
      );

      final eventsCount = (response.data['events'] as List?)?.length ?? 0;
      final totalResults = response.data['totalResults'] ?? 0;
      print('✅ Backend response received: statusCode=${response.statusCode}, eventsCount=$eventsCount, totalResults=$totalResults');

      return ActiveEventsResponse.fromJson(response.data);
    } on DioException catch (e) {
      print('❌ DioException searching nearby events:');
      print('   Status: ${e.response?.statusCode}');
      print('   Message: ${e.response?.data}');
      print('   Error: $e');
      final message = e.response?.data['message'] ?? e.message ?? 'Failed to search nearby events';
      throw Exception(message);
    } catch (e) {
      print('❌ Error searching nearby events: $e');
      rethrow;
    }
  }

  /// Get event details by ID
  Future<Event> getEventDetails(String eventId) async {
    try {
      final response = await _dio.get('/api/events/$eventId');
      return Event.fromMap(response.data);
    } on DioException catch (e) {
      print('Error fetching event details: $e');
      final message = e.response?.data['message'] ?? 'Failed to fetch event details';
      throw Exception(message);
    } catch (e) {
      print('Error fetching event details: $e');
      rethrow;
    }
  }
}

/// Response from Active.com events search
class ActiveEventsResponse {
  final List<Event> events;
  final int totalResults;
  final int page;
  final int perPage;

  ActiveEventsResponse({
    required this.events,
    required this.totalResults,
    required this.page,
    required this.perPage,
  });

  factory ActiveEventsResponse.fromJson(Map<String, dynamic> json) {
    return ActiveEventsResponse(
      events: (json['events'] as List?)
              ?.map((e) => Event.fromMap(e))
              .toList() ??
          [],
      totalResults: json['totalResults'] ?? 0,
      page: json['page'] ?? 1,
      perPage: json['perPage'] ?? 20,
    );
  }
}

