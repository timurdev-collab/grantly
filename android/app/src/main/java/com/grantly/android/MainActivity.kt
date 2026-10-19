package com.grantly.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val Forest = Color(0xFF123E30)
private val DeepForest = Color(0xFF082D23)
private val Ivory = Color(0xFFF8F5ED)
private val Sage = Color(0xFFDDEADB)
private val Gold = Color(0xFFD9B66E)
private val Ink = Color(0xFF19372B)

private enum class Tab(val title: String, val icon: ImageVector) {
    Home("Home", Icons.Outlined.Home),
    Discover("Explore", Icons.Outlined.Search),
    Applications("Applications", Icons.Outlined.Assignment),
    Messages("Messages", Icons.Outlined.ChatBubbleOutline),
    Profile("Profile", Icons.Outlined.PersonOutline)
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { EduTApp() }
    }
}

@Composable
private fun EduTApp() {
    var tab by remember { mutableStateOf(Tab.Home) }
    var requestedDegree by remember { mutableStateOf("All") }
    var selectedScholarship by remember { mutableStateOf<Scholarship?>(null) }
    BackHandler(enabled = selectedScholarship != null) { selectedScholarship = null }
    MaterialTheme(colorScheme = lightColorScheme(primary = Forest, background = Ivory, surface = Ivory)) {
        Scaffold(
            containerColor = Ivory,
            bottomBar = {
                NavigationBar(containerColor = Ivory, tonalElevation = 0.dp) {
                    Tab.entries.forEach { item ->
                        NavigationBarItem(
                            selected = item == tab,
                            onClick = { tab = item; selectedScholarship = null },
                            icon = { Icon(item.icon, contentDescription = null) },
                            label = { Text(item.title, fontSize = 10.sp, maxLines = 1) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = Forest,
                                selectedTextColor = Forest,
                                indicatorColor = Sage,
                                unselectedIconColor = Ink.copy(alpha = .56f),
                                unselectedTextColor = Ink.copy(alpha = .56f)
                            )
                        )
                    }
                }
            }
        ) { padding ->
            LazyColumn(modifier = Modifier.fillMaxSize().padding(padding)) {
                item {
                    Column(Modifier.padding(22.dp)) {
                        if (tab != Tab.Home) {
                            Text("EduT", fontFamily = FontFamily.Serif, fontSize = 25.sp, color = DeepForest)
                            Spacer(Modifier.height(16.dp))
                        }
                        when {
                            selectedScholarship != null -> ScholarshipDetailContent(
                                scholarship = selectedScholarship!!,
                                onBack = { selectedScholarship = null }
                            )
                            tab == Tab.Home -> HomeContent(onDiscover = { degree ->
                                requestedDegree = degree
                                tab = Tab.Discover
                            })
                            tab == Tab.Discover -> ScholarshipDiscoverContent(
                                initialDegree = requestedDegree,
                                onSelect = { selectedScholarship = it }
                            )
                            else -> PlaceholderContent(tab)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun HomeContent(onDiscover: (String) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(32.dp).background(Forest, RoundedCornerShape(50)), contentAlignment = Alignment.Center) {
            Icon(Icons.Outlined.School, contentDescription = null, tint = Ivory, modifier = Modifier.size(19.dp))
        }
        Spacer(Modifier.width(10.dp))
        Text("EduT", fontSize = 21.sp, fontWeight = FontWeight.Bold, color = Forest)
        Spacer(Modifier.weight(1f))
        Text("🌐", fontSize = 19.sp)
        Spacer(Modifier.width(16.dp))
        Icon(Icons.Outlined.NotificationsNone, contentDescription = "Notifications", tint = Forest)
    }
    Spacer(Modifier.height(29.dp))
    Text("Good afternoon", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Forest)
    Spacer(Modifier.height(8.dp))
    Text("Scholarships picked\nfor your next chapter.", fontFamily = FontFamily.Serif, fontSize = 35.sp, lineHeight = 39.sp, color = Ink)
    Spacer(Modifier.height(20.dp))
    Row(
        Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(18.dp)).clickable { onDiscover("All") }.padding(17.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(Icons.Outlined.Search, null, tint = Forest)
        Spacer(Modifier.width(11.dp))
        Text("Search scholarships, countries...", color = Ink.copy(alpha = .65f), fontSize = 14.sp)
        Spacer(Modifier.weight(1f))
        Icon(Icons.Outlined.ArrowForward, null, tint = Forest)
    }
    Spacer(Modifier.height(18.dp))
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(9.dp)) {
        listOf("All", "Bachelor's", "Master's", "PhD").forEachIndexed { i, label ->
            Surface(
                onClick = { onDiscover(label) },
                color = if (i == 0) Forest else Color.White,
                shape = RoundedCornerShape(30.dp)
            ) {
                Text(label, Modifier.padding(horizontal = 12.dp, vertical = 11.dp), color = if (i == 0) Ivory else Forest, fontSize = 12.sp)
            }
        }
    }
    Spacer(Modifier.height(25.dp))
    Column(Modifier.fillMaxWidth().background(DeepForest, RoundedCornerShape(24.dp)).padding(24.dp)) {
        Text("YOUR BEST MATCH", color = Gold, fontSize = 11.sp, letterSpacing = 2.sp)
        Spacer(Modifier.height(12.dp))
        Text("Find the right scholarship\nfor your next chapter.", fontFamily = FontFamily.Serif, fontSize = 27.sp, lineHeight = 33.sp, color = Ivory)
        Spacer(Modifier.height(14.dp))
        Text("Complete your profile to discover personalized opportunities.", color = Sage, fontSize = 13.sp, lineHeight = 19.sp)
        Spacer(Modifier.height(16.dp))
        OutlinedButton(onClick = { onDiscover("All") }, border = BorderStroke(1.dp, Sage.copy(alpha=.6f))) {
            Text("Explore scholarships", color = Ivory)
        }
    }
    Spacer(Modifier.height(25.dp))
    Text("Picked for you", fontFamily = FontFamily.Serif, fontSize = 28.sp, color = Ink)
    Spacer(Modifier.height(7.dp))
    Text("Recommendations will appear after your account is connected.", fontSize = 13.sp, color = Ink.copy(alpha = .68f))
    Spacer(Modifier.height(20.dp))
    Text("Closing soon", fontFamily = FontFamily.Serif, fontSize = 26.sp, color = Ink)
    Spacer(Modifier.height(7.dp))
    Text("Verified scholarship deadlines will appear here.", fontSize = 13.sp, color = Ink.copy(alpha = .68f))
    Spacer(Modifier.height(26.dp))
    Column(Modifier.fillMaxWidth().background(Sage, RoundedCornerShape(22.dp)).padding(20.dp)) {
        Text("Need a little guidance?", fontFamily = FontFamily.Serif, fontSize = 23.sp, color = Forest)
        Spacer(Modifier.height(7.dp))
        Text("Connect with an educational advisor for help planning your journey.", fontSize = 13.sp, color = Ink)
    }
}

@Composable
private fun DiscoverContent(initialDegree: String) {
    var query by remember { mutableStateOf("") }
    var level by remember(initialDegree) { mutableStateOf(initialDegree) }
    Column {
        Text("Explore opportunities", fontFamily = FontFamily.Serif, fontSize = 35.sp, color = Ink)
        Spacer(Modifier.height(8.dp))
        Text("Discover scholarships that align with your plans.", color = Ink.copy(alpha=.7f), fontSize = 14.sp)
        Spacer(Modifier.height(20.dp))
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            leadingIcon = { Icon(Icons.Outlined.Search, null) },
            label = { Text("Search scholarships, universities, countries") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(20.dp)
        )
        Spacer(Modifier.height(16.dp))
        Text("Study level", fontWeight = FontWeight.SemiBold, color = Forest)
        Spacer(Modifier.height(10.dp))
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(7.dp)) {
            listOf("All", "Bachelor's", "Master's", "PhD").forEach { option ->
                FilterChip(
                    selected = option == level,
                    onClick = { level = option },
                    label = { Text(option, fontSize = 11.sp) }
                )
            }
        }
        Spacer(Modifier.height(22.dp))
        Text("Scholarship results", fontFamily = FontFamily.Serif, fontSize = 26.sp, color = Ink)
        Spacer(Modifier.height(11.dp))
        Column(Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(20.dp)).padding(21.dp)) {
            Text("Connect to explore live opportunities", fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Forest)
            Spacer(Modifier.height(8.dp))
            Text("This Android preview uses the iPhone layout. Search and study-level controls are local previews until the Supabase scholarship API is connected.", fontSize = 13.sp, lineHeight = 20.sp, color = Ink.copy(alpha=.7f))
        }
    }
}

@Composable
private fun PlaceholderContent(tab: Tab) {
    Text(tab.title, fontFamily = FontFamily.Serif, fontSize = 38.sp, color = DeepForest)
    Spacer(Modifier.height(12.dp))
    Text(
        "Android development in progress. This screen will match the corresponding EduT iPhone screen. No live account data is connected in this foundation build.",
        color = Ink.copy(alpha = .75f),
        fontSize = 15.sp,
        lineHeight = 23.sp
    )
}
