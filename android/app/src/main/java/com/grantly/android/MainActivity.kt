package com.grantly.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
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
    Discover("Discover", Icons.Outlined.Search),
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
    MaterialTheme(colorScheme = lightColorScheme(primary = Forest, background = Ivory, surface = Ivory)) {
        Scaffold(
            containerColor = Ivory,
            bottomBar = {
                NavigationBar(containerColor = Ivory, tonalElevation = 0.dp) {
                    Tab.entries.forEach { item ->
                        NavigationBarItem(
                            selected = item == tab,
                            onClick = { tab = item },
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
                        Text("EduT", fontFamily = FontFamily.Serif, fontSize = 31.sp, color = DeepForest)
                        Spacer(Modifier.height(20.dp))
                        when (tab) {
                            Tab.Home -> HomeContent(onDiscover = { tab = Tab.Discover })
                            else -> PlaceholderContent(tab)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun HomeContent(onDiscover: () -> Unit) {
    Text("YOUR FUTURE STARTS HERE", fontSize = 11.sp, letterSpacing = 2.sp, color = Forest, fontWeight = FontWeight.SemiBold)
    Spacer(Modifier.height(12.dp))
    Text("Find opportunities\nthat fit you.", fontFamily = FontFamily.Serif, fontSize = 40.sp, lineHeight = 44.sp, color = DeepForest)
    Spacer(Modifier.height(12.dp))
    Text("Scholarships, applications and educational guidance in one thoughtful place.", fontSize = 15.sp, lineHeight = 23.sp, color = Ink.copy(alpha = .75f))
    Spacer(Modifier.height(24.dp))
    Button(onClick = onDiscover, shape = RoundedCornerShape(40.dp), colors = ButtonDefaults.buttonColors(containerColor = Forest)) {
        Text("Explore scholarships"); Spacer(Modifier.width(8.dp)); Icon(Icons.Outlined.ArrowForward, null)
    }
    Spacer(Modifier.height(28.dp))
    Column(Modifier.fillMaxWidth().background(DeepForest, RoundedCornerShape(25.dp)).padding(24.dp)) {
        Text("A WORLD OF POSSIBILITIES", color = Gold, fontSize = 11.sp, letterSpacing = 2.sp)
        Spacer(Modifier.height(12.dp))
        Text("Your next chapter\nstarts here.", fontFamily = FontFamily.Serif, fontSize = 30.sp, color = Ivory, lineHeight = 37.sp)
        Spacer(Modifier.height(18.dp))
        Text("Discover · Organize · Connect", color = Sage, fontSize = 13.sp)
    }
    Spacer(Modifier.height(24.dp))
    Text("Explore EduT", fontFamily = FontFamily.Serif, fontSize = 28.sp, color = Ink)
    Spacer(Modifier.height(12.dp))
    listOf(
        "Discover" to "Find scholarships and universities",
        "Applications" to "Keep your next steps organized",
        "Advisors" to "Get educational guidance"
    ).forEach { (title, detail) ->
        Column(Modifier.fillMaxWidth().padding(vertical = 10.dp).background(Color.White, RoundedCornerShape(20.dp)).padding(20.dp)) {
            Text(title, color = Forest, fontSize = 19.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(5.dp))
            Text(detail, color = Ink.copy(alpha = .7f), fontSize = 14.sp)
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
