/**
 * Active.com API Service
 * 
 * Proxies Active.com API requests to keep the API key secure on the backend.
 * The API key should never be exposed to the client.
 * 
 * Documentation: https://developer.active.com/docs/v2_activity_api_search
 * API Plan: Activity Search API v2
 * 
 * Rate Limits:
 * - 5 calls per second
 * - 500,000 calls per month
 * 
 * API Key should be stored in backend/.env as ACTIVE_DOT_COM_KEY
 */

/**
 * Search for events/activities by zipcode
 * @param {Object} params - Search parameters
 * @param {string} params.zip - Zip code (required)
 * @param {string} params.query - Search query/keywords (optional)
 * @param {string} params.startDate - Start date (YYYY-MM-DD format, optional)
 * @param {string} params.endDate - End date (YYYY-MM-DD format, optional)
 * @param {number} params.page - Page number (default: 1)
 * @param {number} params.perPage - Results per page (default: 50, max: 100)
 * @param {string} apiKey - Active.com API key
 * @returns {Promise<Object>} Search results with events
 */
export async function searchNearbyEvents(params, apiKey) {
  const {
    zip,
    query = '',
    startDate = null,
    endDate = null,
    page = 1,
    perPage = 50,
  } = params;

  // Zipcode is required
  if (!zip) {
    throw new Error('Zipcode is required');
  }

  if (!apiKey) {
    throw new Error('Active.com API key is required');
  }

  // Build the API URL for Activity Search API v2
  // Documentation: https://developer.active.com/docs/v2_activity_api_search
  // Endpoint: http://api.amp.active.com/v2/search/
  const baseUrl = 'http://api.amp.active.com/v2/search/';
  const url = new URL(baseUrl);
  
  // Required: API key
  url.searchParams.append('api_key', apiKey);
  
  // Use zipcode only - simple and predictable
  if (params.zip) {
    url.searchParams.append('zip', params.zip);
    console.log('📍 Using zipcode:', params.zip);
  } else {
    throw new Error('Zipcode is required');
  }
  
  // Filter to events only
  url.searchParams.append('category', 'event');
  
  // Only add query if explicitly provided - don't restrict by default
  if (query && query.trim().length > 0) {
    url.searchParams.append('query', query.trim());
    console.log('🔍 Search query:', query);
  } else {
    console.log('ℹ️ No query parameter - fetching all events for zipcode');
  }
  
  // Pagination
  url.searchParams.append('current_page', page.toString());
  url.searchParams.append('per_page', Math.min(perPage, 100).toString());
  
  // Sort by date descending (newest first) - we'll also sort after filtering
  url.searchParams.append('sort', 'date_desc');
  
  // Exclude children/kids events
  url.searchParams.append('exclude_children', 'true');

  // Log the full URL for debugging
  console.log('🌐 Active.com API URL:', url.toString());

  try {
    const response = await fetch(url.toString(), {
      headers: {
        'Accept': 'application/json',
      },
    });

    console.log('📡 Active.com API Response Status:', response.status);

    if (!response.ok) {
      const errorText = await response.text();
      console.error('❌ Active.com API error:', response.status, errorText);
      throw new Error(`Active.com API returned status ${response.status}: ${errorText}`);
    }

    const data = await response.json();
    
    console.log('📊 Active.com API Response:', {
      total_results: data.total_results,
      items_per_page: data.items_per_page,
      results_count: data.results?.length || 0,
    });
    
    // Log the response for debugging (first event only)
    if (data.results && data.results.length > 0) {
      console.log('✅ Active.com API - First event:', {
        name: data.results[0].assetName,
        id: data.results[0].assetGuid,
        startDate: data.results[0].activityStartDate,
      });
    } else {
      console.log('⚠️ Active.com API returned 0 results');
      console.log('📋 Full response:', JSON.stringify(data, null, 2).substring(0, 500));
    }
    
    // Transform the response based on actual API structure
    const eventsArray = data.results || [];
    
    console.log(`📦 Raw events from API: ${eventsArray.length}`);
    
    // SIMPLIFIED FILTERING - Only exclude obvious kids events
    // Don't be too restrictive, let more events through
    const excludeKeywords = [
      'kids', 'children', 'youth camp', 'day camp', 'overnight camp', 'junior camp'
    ];
    
    const now = new Date();
    
    const filteredEvents = eventsArray.filter(event => {
      const eventName = (event.assetName || '').toLowerCase();
      const eventDesc = (event.assetDescriptions?.[0]?.description || event.assetDsc || '').toLowerCase();
      const eventText = `${eventName} ${eventDesc}`;
      
      // Exclude if it's clearly a kids camp
      const isKidsCamp = excludeKeywords.some(keyword => eventText.includes(keyword));
      
      if (isKidsCamp) {
        console.log(`🚫 Excluding kids event: ${eventName}`);
        return false;
      }
      
      // Exclude expired events (where end date is in the past)
      if (event.activityEndDate) {
        const endDate = new Date(event.activityEndDate);
        if (endDate < now) {
          console.log(`⏰ Excluding expired event: ${eventName} (ended: ${event.activityEndDate})`);
          return false;
        }
      } else if (event.activityStartDate) {
        // If no end date, check start date
        const startDate = new Date(event.activityStartDate);
        if (startDate < now) {
          console.log(`⏰ Excluding expired event: ${eventName} (started: ${event.activityStartDate})`);
          return false;
        }
      }
      
      // Include everything else
      return true;
    });
    
    console.log(`✅ Filtered events: ${filteredEvents.length} (from ${eventsArray.length} total)`);
    
    // Sort events by start date in descending order (most recent/future events first)
    filteredEvents.sort((a, b) => {
      const dateA = a.activityStartDate ? new Date(a.activityStartDate) : new Date(0);
      const dateB = b.activityStartDate ? new Date(b.activityStartDate) : new Date(0);
      return dateB - dateA; // Descending order (newest first)
    });
    
    console.log(`📅 Sorted ${filteredEvents.length} events by start date (descending)`);
    
    const transformedEvents = filteredEvents.map(event => {
      // Extract description from assetDescriptions array
      let description = '';
      if (event.assetDescriptions && event.assetDescriptions.length > 0) {
        // Get the first description, strip HTML tags for basic text
        const descText = event.assetDescriptions[0].description || '';
        // Simple HTML tag removal (you might want a proper HTML parser)
        description = descText.replace(/<[^>]*>/g, '').trim();
      }
      
      // Extract location data from place object
      const place = event.place || {};
      const addressParts = [
        place.addressLine1Txt,
        place.cityName,
        place.stateProvinceCode,
        place.postalCode
      ].filter(Boolean);
      const fullAddress = addressParts.join(', ');
      
      // Get first image URL
      const firstImage = event.assetImages && event.assetImages.length > 0
        ? event.assetImages.find(img => img.imageType === 'IMAGE')?.imageUrlAdr
        : null;
      
      // Log date fields for debugging
      if (event.activityStartDate || event.activityEndDate) {
        console.log(`📅 Event "${event.assetName}" dates:`, {
          activityStartDate: event.activityStartDate,
          activityEndDate: event.activityEndDate,
          startType: typeof event.activityStartDate,
          endType: typeof event.activityEndDate,
        });
      }
      
      return {
        id: event.assetGuid || event.assetId || '',
        name: event.assetName || '',
        description: description || event.assetDsc || '',
        starts_at: event.activityStartDate || null, // Map to starts_at for Flutter model
        ends_at: event.activityEndDate || null, // Map to ends_at for Flutter model
        venue: place.placeName || place.cityName || '',
        address: fullAddress || place.addressLine1Txt || '',
        lat: place.latitude ? parseFloat(place.latitude) : (place.geoPoint?.lat ? parseFloat(place.geoPoint.lat) : null),
        lng: place.longitude ? parseFloat(place.longitude) : (place.geoPoint?.lon ? parseFloat(place.geoPoint.lon) : null),
        zipCode: place.postalCode || null,
        url: event.urlAdr || event.preferredUrlAdr || '',
        registrationUrl: event.registrationUrlAdr || event.urlAdr || '',
        category: event.assetCategories?.[0]?.category?.categoryName || null,
        imageUrl: firstImage || event.logoUrlAdr || null,
      };
    });
    
    return {
      events: transformedEvents,
      totalResults: transformedEvents.length, // Use filtered count
      page: data.current_page || page,
      perPage: data.items_per_page || data.per_page || perPage,
    };
  } catch (error) {
    console.error('Error fetching events from Active.com:', error);
    throw error;
  }
}

/**
 * Get event details by ID
 * @param {string} eventId - Active.com event ID
 * @param {string} apiKey - Active.com API key
 * @returns {Promise<Object>} Event details
 */
export async function getEventDetails(eventId, apiKey) {
  if (!eventId) {
    throw new Error('Event ID is required');
  }

  if (!apiKey) {
    throw new Error('Active.com API key is required');
  }

  // Activity Search API v2 - Get event details
  // Note: Verify the correct endpoint for getting individual event details
  // This might be different from the search endpoint
  // Get event details - Note: Verify the correct endpoint for individual event details
  // This might be a different endpoint than search
  // For now using search with assetGuid filter, or you may need: /v2/assets/{assetGuid}
  const url = new URL('http://api.amp.active.com/v2/search/');
  url.searchParams.append('api_key', apiKey);
  url.searchParams.append('assetGuid', eventId);

  try {
    const response = await fetch(url.toString(), {
      headers: {
        'Accept': 'application/json',
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Active.com API returned status ${response.status}: ${errorText}`);
    }

    const data = await response.json();
    
    // The response should have results array with one event
    const event = data.results && data.results.length > 0 ? data.results[0] : null;
    if (!event) {
      throw new Error('Event not found');
    }
    
    // Extract description
    let description = '';
    if (event.assetDescriptions && event.assetDescriptions.length > 0) {
      const descText = event.assetDescriptions[0].description || '';
      description = descText.replace(/<[^>]*>/g, '').trim();
    }
    
    // Extract location
    const place = event.place || {};
    const addressParts = [
      place.addressLine1Txt,
      place.cityName,
      place.stateProvinceCode,
      place.postalCode
    ].filter(Boolean);
    const fullAddress = addressParts.join(', ');
    
    // Get first image
    const firstImage = event.assetImages && event.assetImages.length > 0
      ? event.assetImages.find(img => img.imageType === 'IMAGE')?.imageUrlAdr
      : null;
    
    // Transform to match our Event model
    return {
      id: event.assetGuid || '',
      name: event.assetName || '',
      description: description || event.assetDsc || '',
      starts_at: event.activityStartDate || null, // Map to starts_at for Flutter model
      ends_at: event.activityEndDate || null, // Map to ends_at for Flutter model
      venue: place.placeName || place.cityName || '',
      address: fullAddress || place.addressLine1Txt || '',
      lat: place.latitude ? parseFloat(place.latitude) : (place.geoPoint?.lat ? parseFloat(place.geoPoint.lat) : null),
      lng: place.longitude ? parseFloat(place.longitude) : (place.geoPoint?.lon ? parseFloat(place.geoPoint.lon) : null),
      zipCode: place.postalCode || null,
      url: event.urlAdr || event.preferredUrlAdr || '',
      registrationUrl: event.registrationUrlAdr || event.urlAdr || '',
      category: event.assetCategories?.[0]?.category?.categoryName || null,
      imageUrl: firstImage || event.logoUrlAdr || null,
    };
  } catch (error) {
    console.error('Error fetching event details from Active.com:', error);
    throw error;
  }
}

