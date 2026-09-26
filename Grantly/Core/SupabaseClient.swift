import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: AppConfig.supabaseURL,
    supabaseKey: AppConfig.supabasePublishableKey
)
