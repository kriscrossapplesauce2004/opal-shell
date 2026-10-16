"""Weather for the Glance widget from Open-Meteo (no key, no account). The user names a city; there is no geolocation."""
import json, os, pathlib, time, urllib.parse, urllib.request

STATE = (pathlib.Path(os.environ['OPAL_STATE_DIR']) if os.environ.get('OPAL_STATE_DIR') else pathlib.Path(os.environ.get('XDG_STATE_HOME') or pathlib.Path.home() / '.local/state') / 'opal') / 'weather.json'
GEOCODE = 'https://geocoding-api.open-meteo.com/v1/search'
FORECAST = 'https://api.open-meteo.com/v1/forecast'
REFRESH = 30 * 60
TIMEOUT = 8
# WMO weather codes: text and Material Symbols names for day and night.
CODES = {
    0: ('Clear', 'clear_day', 'clear_night'), 1: ('Mostly clear', 'partly_cloudy_day', 'partly_cloudy_night'),
    2: ('Partly cloudy', 'partly_cloudy_day', 'partly_cloudy_night'), 3: ('Cloudy', 'cloud', 'cloud'),
    45: ('Fog', 'foggy', 'foggy'), 48: ('Fog', 'foggy', 'foggy'),
    51: ('Drizzle', 'rainy_light', 'rainy_light'), 53: ('Drizzle', 'rainy_light', 'rainy_light'), 55: ('Drizzle', 'rainy', 'rainy'),
    56: ('Freezing drizzle', 'weather_mix', 'weather_mix'), 57: ('Freezing drizzle', 'weather_mix', 'weather_mix'),
    61: ('Light rain', 'rainy_light', 'rainy_light'), 63: ('Rain', 'rainy', 'rainy'), 65: ('Heavy rain', 'rainy_heavy', 'rainy_heavy'),
    66: ('Freezing rain', 'weather_mix', 'weather_mix'), 67: ('Freezing rain', 'weather_mix', 'weather_mix'),
    71: ('Light snow', 'weather_snowy', 'weather_snowy'), 73: ('Snow', 'weather_snowy', 'weather_snowy'), 75: ('Heavy snow', 'snowing_heavy', 'snowing_heavy'),
    77: ('Snow grains', 'weather_snowy', 'weather_snowy'), 80: ('Showers', 'rainy', 'rainy'), 81: ('Showers', 'rainy', 'rainy'), 82: ('Heavy showers', 'rainy_heavy', 'rainy_heavy'),
    85: ('Snow showers', 'weather_snowy', 'weather_snowy'), 86: ('Snow showers', 'snowing_heavy', 'snowing_heavy'),
    95: ('Thunderstorm', 'thunderstorm', 'thunderstorm'), 96: ('Thunderstorm', 'thunderstorm', 'thunderstorm'), 99: ('Thunderstorm', 'thunderstorm', 'thunderstorm'),
}


def fetch_json(url, opener=urllib.request.urlopen):
    request = urllib.request.Request(url, headers={'User-Agent': 'Opal shell weather'})
    with opener(request, timeout=TIMEOUT) as response:
        body = response.read(200_000)
    return json.loads(body.decode('utf-8'))


def geocode(city, fetch=fetch_json):
    """Return {name, lat, lon, country} for a city name, or None."""
    city = str(city or '').strip()
    if not city or len(city) > 80: return None
    data = fetch(GEOCODE + '?' + urllib.parse.urlencode({'name': city, 'count': 1, 'language': 'en', 'format': 'json'}))
    results = data.get('results') or []
    if not results: return None
    r = results[0]
    try: return {'name': str(r.get('name') or city)[:80], 'country': str(r.get('country_code') or '')[:4], 'lat': float(r['latitude']), 'lon': float(r['longitude'])}
    except (KeyError, TypeError, ValueError): return None


def parse_forecast(data, place):
    """Turn an Open-Meteo forecast into the widget payload."""
    current = data.get('current') or {}
    daily = data.get('daily') or {}
    try:
        code = int(current.get('weather_code', -1))
        temp = round(float(current['temperature_2m']))
    except (KeyError, TypeError, ValueError):
        return None
    text, day_icon, night_icon = CODES.get(code, ('Weather', 'thermostat', 'thermostat'))
    high = (daily.get('temperature_2m_max') or [None])[0]
    low = (daily.get('temperature_2m_min') or [None])[0]
    unit = (data.get('current_units') or {}).get('temperature_2m', '°C')
    return {'place': place.get('name', ''), 'temp': temp, 'unit': '°' if unit.startswith('°') else unit, 'text': text,
            'icon': day_icon if current.get('is_day', 1) else night_icon,
            'high': round(high) if isinstance(high, (int, float)) else None, 'low': round(low) if isinstance(low, (int, float)) else None}


def forecast(place, fetch=fetch_json, fahrenheit=False):
    query = {'latitude': f"{place['lat']:.4f}", 'longitude': f"{place['lon']:.4f}", 'current': 'temperature_2m,weather_code,is_day',
             'daily': 'temperature_2m_max,temperature_2m_min', 'timezone': 'auto', 'forecast_days': 1}
    if fahrenheit: query['temperature_unit'] = 'fahrenheit'
    return parse_forecast(fetch(FORECAST + '?' + urllib.parse.urlencode(query)), place)


def load(path=STATE):
    try: return json.loads(path.read_text())
    except (OSError, ValueError): return {}


def save(state, path=STATE):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(state))
    os.replace(temp, path)


def update(city, fahrenheit=False, now=None, fetch=fetch_json, path=STATE, force=False):
    """Return the weather payload for the city. It uses the cache when it is fresh and keeps the last value when the network fails."""
    now = time.time() if now is None else now
    state = load(path)
    if not city: return None
    same = state.get('city') == city and state.get('fahrenheit') == bool(fahrenheit)
    if same and not force and now - state.get('fetched', 0) < REFRESH and state.get('data'):
        return state['data']
    try:
        place = state.get('place') if state.get('city') == city and state.get('place') else geocode(city, fetch)
        if not place: return None
        data = forecast(place, fetch, fahrenheit)
        if data:
            save({'city': city, 'fahrenheit': bool(fahrenheit), 'place': place, 'fetched': now, 'data': data}, path)
            return data
    except (OSError, ValueError, KeyError):
        pass
    return state.get('data') if same else None
