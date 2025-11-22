package com.linku.app.ui.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.linku.app.ui.screens.fleamarket.FleaMarketScreen
import com.linku.app.ui.screens.fleamarket.PublishFleaMarketScreen
import com.linku.app.ui.screens.home.HomeScreen
import com.linku.app.ui.screens.login.LoginScreen
import com.linku.app.ui.screens.message.MessageScreen
import com.linku.app.ui.screens.profile.ProfileScreen
import com.linku.app.ui.screens.tasks.PublishTaskScreen
import com.linku.app.ui.screens.tasks.TasksScreen
import com.linku.app.viewmodel.AuthViewModel

@Composable
fun AppNavigation(
    authViewModel: AuthViewModel = androidx.lifecycle.viewmodel.compose.viewModel()
) {
    val navController = rememberNavController()
    val isAuthenticated by authViewModel.isAuthenticated.collectAsState()
    
    if (isAuthenticated) {
        MainNavigation(navController = navController)
    } else {
        LoginScreen(
            viewModel = authViewModel,
            onLoginSuccess = {
                // 登录成功后导航到主页
            }
        )
    }
}

@Composable
fun MainNavigation(navController: NavHostController) {
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination
    
    Scaffold(
        bottomBar = {
            NavigationBar {
                val destinations = listOf(
                    "home" to Icons.Default.Home to "首页",
                    "tasks" to Icons.Default.List to "任务",
                    "fleamarket" to Icons.Default.Store to "跳蚤市场",
                    "message" to Icons.Default.Message to "消息",
                    "profile" to Icons.Default.Person to "我的"
                )
                
                destinations.forEach { (route, icon, label) ->
                    NavigationBarItem(
                        icon = { Icon(icon, contentDescription = null) },
                        label = { Text(label) },
                        selected = currentDestination?.hierarchy?.any { it.route == route } == true,
                        onClick = {
                            navController.navigate(route) {
                                popUpTo(navController.graph.startDestinationId)
                                launchSingleTop = true
                            }
                        }
                    )
                }
            }
        }
    ) { paddingValues ->
        NavHost(
            navController = navController,
            startDestination = "home",
            modifier = Modifier.padding(paddingValues)
        ) {
            composable("home") {
                HomeScreen()
            }
            composable("tasks") {
                TasksScreen(navController = navController)
            }
            composable("fleamarket") {
                FleaMarketScreen()
            }
            composable("message") {
                MessageScreen()
            }
            composable("profile") {
                ProfileScreen()
            }
            composable(
                "tasks/{taskId}",
                arguments = listOf(navArgument("taskId") { type = NavType.IntType })
            ) { backStackEntry ->
                val taskId = backStackEntry.arguments?.getInt("taskId") ?: 0
                com.linku.app.ui.screens.tasks.TaskDetailScreen(taskId = taskId)
            }
            composable("publish/task") {
                PublishTaskScreen(navController = navController)
            }
            composable("publish/fleamarket") {
                PublishFleaMarketScreen(navController = navController)
            }
        }
    }
}

