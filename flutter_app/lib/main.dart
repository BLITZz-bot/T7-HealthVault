import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
// Conditional import: stub (no-op) for Android/iOS, FFI init for Windows/Linux/macOS
import 'db_init_stub.dart'
    if (dart.library.ffi) 'db_init_desktop.dart';

void main() {
  initializeDatabase(); // no-op on mobile, FFI init on desktop
  runApp(const HealthVaultApp());
}

    class HealthVaultApp extends StatelessWidget {                                                
      const HealthVaultApp({super.key});                                                          
                                                                                                  
      @override                                                                                   
      Widget build(BuildContext context) {                                                        
        return MaterialApp(                                                                       
          title: 'T7 HealthVault',                                                                
          debugShowCheckedModeBanner: false,                                                      
          theme: ThemeData(                                                                       
            useMaterial3: true,                                                                   
            colorScheme: ColorScheme.fromSeed(                                                    
              seedColor: const Color(0xFF00897B), // Healthcare Teal Theme                        
              brightness: Brightness.light,                                                       
            ),                                                                                    
            inputDecorationTheme: InputDecorationTheme(                                           
              filled: true,                                                                       
              fillColor: Colors.teal.shade50.withValues(alpha: 0.5),                                    
              border: OutlineInputBorder(                                                         
                borderRadius: BorderRadius.circular(12),                                          
                borderSide: BorderSide.none,                                                      
              ),                                                                                  
              focusedBorder: OutlineInputBorder(                                                  
                borderRadius: BorderRadius.circular(12),                                          
                borderSide: const BorderSide(color: Color(0xFF00897B), width: 2),                 
              ),                                                                                  
            ),                                                                                    
            elevatedButtonTheme: ElevatedButtonThemeData(                                         
              style: ElevatedButton.styleFrom(                                                    
                backgroundColor: const Color(0xFF00897B),                                         
                foregroundColor: Colors.white,                                                    
                minimumSize: const Size(double.infinity, 50),                                     
                shape: RoundedRectangleBorder(                                                    
                  borderRadius: BorderRadius.circular(12),                                        
                ),                                                                                
              ),                                                                                  
            ),                                                                                    
          ),                                                                                      
          home: const LoginScreen(),                                                              
        );                                                                                        
      }                                                                                           
    }