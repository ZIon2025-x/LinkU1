package com.link2ur.link2ur

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Geocoder
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.OnMapReadyCallback
import com.google.android.gms.maps.SupportMapFragment
import com.google.android.gms.maps.model.LatLng
import com.google.android.material.button.MaterialButton
import com.google.android.material.floatingactionbutton.FloatingActionButton
import java.io.IOException
import java.util.Locale

class LocationPickerActivity : AppCompatActivity(), OnMapReadyCallback {

    companion object {
        const val EXTRA_INITIAL_LAT = "initialLatitude"
        const val EXTRA_INITIAL_LNG = "initialLongitude"
        const val EXTRA_INITIAL_ADDR = "initialAddress"
        const val RESULT_ADDRESS = "address"
        const val RESULT_LATITUDE = "latitude"
        const val RESULT_LONGITUDE = "longitude"
        private const val LOCATION_PERMISSION_REQUEST = 1001
        private const val DEFAULT_LAT = 51.5074
        private const val DEFAULT_LNG = -0.1278
        private const val DEFAULT_ZOOM = 15f
    }

    private var googleMap: GoogleMap? = null
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private val handler = Handler(Looper.getMainLooper())
    private var geocodeRunnable: Runnable? = null

    // Views
    private lateinit var searchEditText: EditText
    private lateinit var clearSearch: ImageView
    private lateinit var addressText: TextView
    private lateinit var coordinateText: TextView
    private lateinit var addressLoading: ProgressBar
    private lateinit var confirmBtn: MaterialButton
    private lateinit var currentLocationBtn: MaterialButton
    private lateinit var onlineBtn: MaterialButton
    private lateinit var myLocationFab: FloatingActionButton
    private lateinit var citiesContainer: LinearLayout

    // State
    private var currentAddress = ""
    private var isMapMoving = false

    // Popular UK cities
    private val popularCities = listOf(
        Triple("London", 51.5074, -0.1278),
        Triple("Birmingham", 52.4862, -1.8904),
        Triple("Manchester", 53.4808, -2.2426),
        Triple("Leeds", 53.8008, -1.5491),
        Triple("Liverpool", 53.4084, -2.9916),
        Triple("Bristol", 51.4545, -2.5879),
        Triple("Edinburgh", 55.9533, -3.1883),
        Triple("Glasgow", 55.8642, -4.2518),
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_location_picker)

        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)

        initViews()
        setupSearchBar()
        setupCityChips()
        setupButtons()

        val mapFragment = supportFragmentManager.findFragmentById(R.id.map) as SupportMapFragment
        mapFragment.getMapAsync(this)
    }

    private fun initViews() {
        searchEditText = findViewById(R.id.searchEditText)
        clearSearch = findViewById(R.id.clearSearch)
        addressText = findViewById(R.id.addressText)
        coordinateText = findViewById(R.id.coordinateText)
        addressLoading = findViewById(R.id.addressLoading)
        confirmBtn = findViewById(R.id.confirmBtn)
        currentLocationBtn = findViewById(R.id.currentLocationBtn)
        onlineBtn = findViewById(R.id.onlineBtn)
        myLocationFab = findViewById(R.id.myLocationFab)
        citiesContainer = findViewById(R.id.citiesContainer)
    }

    private fun setupSearchBar() {
        var searchDebounce: Runnable? = null

        searchEditText.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                val query = s?.toString()?.trim() ?: ""
                clearSearch.visibility = if (query.isNotEmpty()) View.VISIBLE else View.GONE

                searchDebounce?.let { handler.removeCallbacks(it) }
                if (query.length >= 2) {
                    searchDebounce = Runnable { geocodeSearch(query) }
                    handler.postDelayed(searchDebounce!!, 500)
                }
            }
        })

        searchEditText.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_SEARCH) {
                val query = searchEditText.text.toString().trim()
                if (query.isNotEmpty()) geocodeSearch(query)
                hideKeyboard()
                true
            } else false
        }

        clearSearch.setOnClickListener {
            searchEditText.setText("")
            hideKeyboard()
        }
    }

    private fun setupCityChips() {
        for (city in popularCities) {
            val chip = TextView(this).apply {
                text = city.first
                setTextColor(ContextCompat.getColor(context, android.R.color.black))
                textSize = 12f
                setPadding(dp(12), dp(8), dp(12), dp(8))
                setBackgroundResource(R.drawable.city_chip_bg)
                val params = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
                params.marginEnd = dp(8)
                layoutParams = params
                setOnClickListener {
                    moveTo(LatLng(city.second, city.third), 13f)
                }
            }
            citiesContainer.addView(chip)
        }
    }

    private fun setupButtons() {
        confirmBtn.setOnClickListener {
            googleMap?.let { map ->
                val center = map.cameraPosition.target
                val data = Intent().apply {
                    putExtra(RESULT_ADDRESS, currentAddress)
                    putExtra(RESULT_LATITUDE, center.latitude)
                    putExtra(RESULT_LONGITUDE, center.longitude)
                }
                setResult(Activity.RESULT_OK, data)
                finish()
            }
        }

        currentLocationBtn.setOnClickListener { requestCurrentLocation() }
        myLocationFab.setOnClickListener { requestCurrentLocation() }

        onlineBtn.setOnClickListener {
            val data = Intent().apply {
                putExtra(RESULT_ADDRESS, "Online")
                putExtra(RESULT_LATITUDE, 0.0)
                putExtra(RESULT_LONGITUDE, 0.0)
            }
            setResult(Activity.RESULT_OK, data)
            finish()
        }

        findViewById<ImageButton>(R.id.zoomInBtn).setOnClickListener {
            googleMap?.animateCamera(CameraUpdateFactory.zoomIn())
        }
        findViewById<ImageButton>(R.id.zoomOutBtn).setOnClickListener {
            googleMap?.animateCamera(CameraUpdateFactory.zoomOut())
        }
    }

    override fun onMapReady(map: GoogleMap) {
        googleMap = map

        map.uiSettings.apply {
            isMyLocationButtonEnabled = false  // We use our own FAB
            isZoomControlsEnabled = false       // We use our own buttons
            isCompassEnabled = true
            isMapToolbarEnabled = false
        }

        // Camera idle listener → reverse geocode center
        map.setOnCameraIdleListener {
            isMapMoving = false
            val center = map.cameraPosition.target
            updateCoordinateText(center)
            reverseGeocode(center)
        }

        map.setOnCameraMoveStartedListener {
            isMapMoving = true
            addressText.text = "Moving..."
            addressText.setTextColor(ContextCompat.getColor(this, android.R.color.darker_gray))
        }

        // Initialize position
        val initLat = intent.getDoubleExtra(EXTRA_INITIAL_LAT, 0.0)
        val initLng = intent.getDoubleExtra(EXTRA_INITIAL_LNG, 0.0)
        val initAddr = intent.getStringExtra(EXTRA_INITIAL_ADDR)

        if (initLat != 0.0 && initLng != 0.0) {
            val pos = LatLng(initLat, initLng)
            map.moveCamera(CameraUpdateFactory.newLatLngZoom(pos, DEFAULT_ZOOM))
            if (!initAddr.isNullOrEmpty()) {
                currentAddress = initAddr
                addressText.text = initAddr
                addressText.setTextColor(ContextCompat.getColor(this, android.R.color.black))
                confirmBtn.isEnabled = true
            }
        } else if (!initAddr.isNullOrEmpty() && initAddr.lowercase() != "online") {
            geocodeSearch(initAddr)
        } else {
            requestCurrentLocation()
        }

        enableMyLocationLayer()
    }

    private fun reverseGeocode(latLng: LatLng) {
        geocodeRunnable?.let { handler.removeCallbacks(it) }
        addressLoading.visibility = View.VISIBLE

        geocodeRunnable = Runnable {
            try {
                val geocoder = Geocoder(this, Locale.getDefault())
                @Suppress("DEPRECATION")
                val addresses = geocoder.getFromLocation(latLng.latitude, latLng.longitude, 1)
                runOnUiThread {
                    addressLoading.visibility = View.GONE
                    if (!addresses.isNullOrEmpty()) {
                        val addr = addresses[0]
                        val parts = mutableListOf<String>()
                        addr.featureName?.let { if (it != addr.locality && it != addr.subLocality) parts.add(it) }
                        addr.thoroughfare?.let { parts.add(it) }
                        addr.subLocality?.let { parts.add(it) }
                        addr.locality?.let { parts.add(it) }
                        addr.postalCode?.let { parts.add(it) }
                        if (parts.isEmpty()) addr.adminArea?.let { parts.add(it) }
                        if (parts.isEmpty()) addr.countryName?.let { parts.add(it) }

                        currentAddress = if (parts.isNotEmpty()) parts.joinToString(", ") else "Unknown location"
                        addressText.text = currentAddress
                        addressText.setTextColor(ContextCompat.getColor(this, android.R.color.black))
                        confirmBtn.isEnabled = true
                    } else {
                        currentAddress = String.format("%.6f, %.6f", latLng.latitude, latLng.longitude)
                        addressText.text = currentAddress
                        addressText.setTextColor(ContextCompat.getColor(this, android.R.color.darker_gray))
                        confirmBtn.isEnabled = true
                    }
                }
            } catch (e: IOException) {
                runOnUiThread {
                    addressLoading.visibility = View.GONE
                    currentAddress = String.format("%.6f, %.6f", latLng.latitude, latLng.longitude)
                    addressText.text = currentAddress
                    confirmBtn.isEnabled = true
                }
            }
        }
        Thread(geocodeRunnable!!).start()
    }

    private fun geocodeSearch(query: String) {
        Thread {
            try {
                val geocoder = Geocoder(this, Locale.getDefault())
                @Suppress("DEPRECATION")
                val results = geocoder.getFromLocationName(query, 1)
                runOnUiThread {
                    if (!results.isNullOrEmpty()) {
                        val loc = results[0]
                        val pos = LatLng(loc.latitude, loc.longitude)
                        moveTo(pos, DEFAULT_ZOOM)
                    }
                }
            } catch (_: IOException) {
                // Geocoding failed silently
            }
        }.start()
    }

    private fun moveTo(latLng: LatLng, zoom: Float) {
        googleMap?.animateCamera(CameraUpdateFactory.newLatLngZoom(latLng, zoom))
    }

    private fun updateCoordinateText(latLng: LatLng) {
        coordinateText.text = String.format("%.6f, %.6f", latLng.latitude, latLng.longitude)
    }

    @SuppressLint("MissingPermission")
    private fun requestCurrentLocation() {
        if (!hasLocationPermission()) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ),
                LOCATION_PERMISSION_REQUEST
            )
            return
        }

        fusedLocationClient.lastLocation.addOnSuccessListener { location ->
            if (location != null) {
                moveTo(LatLng(location.latitude, location.longitude), DEFAULT_ZOOM)
            } else {
                // Fallback to default (London)
                moveTo(LatLng(DEFAULT_LAT, DEFAULT_LNG), DEFAULT_ZOOM)
            }
        }.addOnFailureListener {
            moveTo(LatLng(DEFAULT_LAT, DEFAULT_LNG), DEFAULT_ZOOM)
        }
    }

    @SuppressLint("MissingPermission")
    private fun enableMyLocationLayer() {
        if (hasLocationPermission()) {
            googleMap?.isMyLocationEnabled = true
        }
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == LOCATION_PERMISSION_REQUEST) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                enableMyLocationLayer()
                requestCurrentLocation()
            }
        }
    }

    private fun hideKeyboard() {
        val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
        imm.hideSoftInputFromWindow(searchEditText.windowToken, 0)
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    @Deprecated("Use OnBackPressedCallback instead")
    override fun onBackPressed() {
        setResult(Activity.RESULT_CANCELED)
        @Suppress("DEPRECATION")
        super.onBackPressed()
    }
}
