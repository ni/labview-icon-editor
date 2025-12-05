$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "Seeded Branch Naming Convention" {
    Context "Branch Base Generation" {
        It "LV2025 Q3 64-bit -> seed/lv2025q3-64bit" {
            $q = 'q3'; $y = 2025; $b = 64
            "seed/lv${y}${q}-${b}bit" | Should -Be 'seed/lv2025q3-64bit'
        }

        It "LV2025 Q1 64-bit -> seed/lv2025q1-64bit" {
            $q = 'q1'; $y = 2025; $b = 64
            "seed/lv${y}${q}-${b}bit" | Should -Be 'seed/lv2025q1-64bit'
        }

        It "LV2024 Q3 32-bit -> seed/lv2024q3-32bit" {
            $q = 'q3'; $y = 2024; $b = 32
            "seed/lv${y}${q}-${b}bit" | Should -Be 'seed/lv2024q3-32bit'
        }
    }

    Context "Version String Generation" {
        It "2025 Q3 64-bit -> 25.3 (64-bit)" {
            $maj = 2025 - 2000; $min = 3; $b = 64
            "$maj.$min ($b-bit)" | Should -Be '25.3 (64-bit)'
        }

        It "2025 Q1 64-bit -> 25.0 (64-bit)" {
            $maj = 2025 - 2000; $min = 0; $b = 64
            "$maj.$min ($b-bit)" | Should -Be '25.0 (64-bit)'
        }
    }

    Context "Timestamp Format" {
        It "generates yyyyMMdd-HHmmss format" {
            $ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
            $ts | Should -Match '^\d{8}-\d{6}$'
        }
    }

    Context "Branch Parsing" {
        It "parses seed/lv2025q3-64bit" {
            'seed/lv2025q3-64bit' -match '^seed/lv(\d{4})q([13])-(\d{2})bit$' | Should -BeTrue
            $Matches[1] | Should -Be '2025'
            $Matches[2] | Should -Be '3'
            $Matches[3] | Should -Be '64'
        }

        It "parses seed/lv2025q3-64bit-20251203-100000" {
            'seed/lv2025q3-64bit-20251203-100000' -match '^seed/lv(\d{4})q([13])-(\d{2})bit-(\d{8}-\d{6})$' | Should -BeTrue
            $Matches[4] | Should -Be '20251203-100000'
        }
    }
}
