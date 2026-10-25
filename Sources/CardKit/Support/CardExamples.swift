//
//  CardExamples.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  A card for each kind of report the fleet sends, every number invented.
//  They are the gallery, the examples a tool prints for an agent to copy, and
//  the test that every block draws.
//

import Foundation

public struct CardExample: Sendable {
    public var name: String
    public var about: String
    public var json: String
}

public enum CardExamples {

    public static func named(_ name: String) -> CardExample? { all.first { $0.name == name } }

    public static let all: [CardExample] = [
        CardExample(name: "today", about: "A morning brief: weather, the day, what's due, bills, two figures", json: #"""
        {"eyebrow": "Good morning · Sun 26 Oct",
         "hero": {"value": "14°", "unit": "high 16 · low 8", "detail": "Dry until 3 pm, then showers", "symbol": "cloud.sun.rain.fill"},
         "blocks": [
          {"type": "list", "label": "Today", "rows": [
            {"lead": "10:00", "title": "Swim lesson", "detail": "Leisure centre · leave 9:40"},
            {"lead": "13:00", "title": "Lunch with Sam", "detail": "The Corner Kitchen"},
            {"lead": "18:30", "title": "Collect parcel", "detail": "Post office, closes 19:00"}]},
          {"type": "list", "label": "Due", "rows": [
            {"title": "Renew car insurance", "detail": "Expires today", "status": "critical"},
            {"title": "Water the plants", "done": false},
            {"title": "Book the dentist", "done": true},
            {"symbol": "calendar", "title": "Streaming", "detail": "Tue", "value": {"amount": "10.99", "currency": "GBP"}},
            {"symbol": "calendar", "title": "Phone", "detail": "Thu", "value": {"amount": "18.00", "currency": "GBP"}}]},
          {"type": "tiles", "tiles": [
            {"label": "Yesterday", "value": 2140, "unit": "kcal", "detail": "of 2,209", "status": "good"},
            {"label": "October", "value": "£612 left", "detail": "9 days to go"}]}],
         "footnote": "Weather for your home postcode. Reply \"done\" to tick a task."}
        """#),

        CardExample(name: "spend", about: "One spend just logged, and its category against its budget", json: #"""
        {"eyebrow": "Spent · 12:42",
         "hero": {"value": {"amount": "4.20", "currency": "GBP"}, "label": "Corner Café", "tags": [{"name": "Coffee", "slot": 4}]},
         "status": {"status": "neutral", "text": "£612 left in October's budget · 9 days"},
         "blocks": [{"type": "limits", "rows": [{"name": "Coffee in October", "value": {"amount": "63.40", "currency": "GBP"}, "of": {"amount": "50", "currency": "GBP"}, "slot": 4}]}],
         "footnote": "From your message. Reply to change the amount or the category."}
        """#),

        CardExample(name: "budget", about: "What's left of a monthly budget, fullest category first", json: #"""
        {"eyebrow": "October budget · 9 days left",
         "blocks": [{"type": "limits", "days_left": 9, "total": {"amount": "1800", "currency": "GBP"}, "rows": [
           {"name": "Groceries", "value": {"amount": "212.35", "currency": "GBP"}, "of": {"amount": "300", "currency": "GBP"}, "slot": 1},
           {"name": "Eating out", "value": {"amount": "188.20", "currency": "GBP"}, "of": {"amount": "150", "currency": "GBP"}, "slot": 2},
           {"name": "Transport", "value": {"amount": "64", "currency": "GBP"}, "of": {"amount": "120", "currency": "GBP"}, "slot": 3},
           {"name": "Coffee", "value": {"amount": "63.40", "currency": "GBP"}, "of": {"amount": "50", "currency": "GBP"}, "slot": 4},
           {"name": "Shopping", "value": {"amount": "254.45", "currency": "GBP"}, "of": {"amount": "300", "currency": "GBP"}, "slot": 5},
           {"name": "Bills", "value": {"amount": "406", "currency": "GBP"}, "of": {"amount": "430", "currency": "GBP"}, "slot": 6}]}],
         "footnote": "Fullest first. Two categories are over; the rest have room."}
        """#),

        CardExample(name: "spending", about: "Where the money went, with each category's change since last month", json: #"""
        {"eyebrow": "October so far · 22 days",
         "blocks": [{"type": "breakdown", "reference": {"value": {"amount": "1282.40", "currency": "GBP"}, "label": "September by now"}, "rows": [
           {"name": "Groceries", "value": {"amount": "212.35", "currency": "GBP"}, "previous": {"amount": "243.10", "currency": "GBP"}, "slot": 1},
           {"name": "Eating out", "value": {"amount": "188.20", "currency": "GBP"}, "previous": {"amount": "136.40", "currency": "GBP"}, "slot": 2},
           {"name": "Transport", "value": {"amount": "64", "currency": "GBP"}, "previous": {"amount": "71.50", "currency": "GBP"}, "slot": 3},
           {"name": "Coffee", "value": {"amount": "63.40", "currency": "GBP"}, "previous": {"amount": "54.10", "currency": "GBP"}, "slot": 4},
           {"name": "Shopping", "value": {"amount": "254.45", "currency": "GBP"}, "previous": {"amount": "214.90", "currency": "GBP"}, "slot": 5},
           {"name": "Bills", "value": {"amount": "406", "currency": "GBP"}, "previous": {"amount": "406", "currency": "GBP"}, "slot": 6}]}],
         "footnote": "Change is against all of September. Most visits: a supermarket, £164 over 9 trips."}
        """#),

        CardExample(name: "on-track", about: "Spending so far against last month and the budget's pace", json: #"""
        {"eyebrow": "October · day 22 of 31",
         "blocks": [{"type": "trend", "end": 31, "series": [
           {"name": "October", "points": [
             {"x": 1, "value": {"amount": "12", "currency": "GBP"}}, {"x": 4, "value": {"amount": "130", "currency": "GBP"}},
             {"x": 8, "value": {"amount": "300", "currency": "GBP"}}, {"x": 12, "value": {"amount": "470", "currency": "GBP"}},
             {"x": 16, "value": {"amount": "663", "currency": "GBP"}}, {"x": 20, "value": {"amount": "868", "currency": "GBP"}},
             {"x": 21, "value": {"amount": "1103", "currency": "GBP"}}, {"x": 22, "value": {"amount": "1188.40", "currency": "GBP"}}]},
           {"name": "September", "points": [
             {"x": 1, "value": {"amount": "0", "currency": "GBP"}}, {"x": 4, "value": {"amount": "141", "currency": "GBP"}},
             {"x": 8, "value": {"amount": "301", "currency": "GBP"}}, {"x": 12, "value": {"amount": "480", "currency": "GBP"}},
             {"x": 16, "value": {"amount": "641", "currency": "GBP"}}, {"x": 20, "value": {"amount": "860", "currency": "GBP"}},
             {"x": 21, "value": {"amount": "1205", "currency": "GBP"}}, {"x": 22, "value": {"amount": "1282.40", "currency": "GBP"}},
             {"x": 26, "value": {"amount": "1415", "currency": "GBP"}}, {"x": 30, "value": {"amount": "1636", "currency": "GBP"}}]}],
           "target": {"value": {"amount": "1800", "currency": "GBP"}, "at": 31, "label": "budget"}}],
         "footnote": "The jump on day 21 was rent."}
        """#),

        CardExample(name: "meal", about: "A meal: energy, protein/carbs/fat rings, an allergy warning, what was in it", json: #"""
        {"eyebrow": "Dinner · 19:30",
         "hero": {"value": 1400, "unit": "kcal"},
         "status": {"status": "critical", "text": "Peanuts and sesame may be in the chocolate cake"},
         "blocks": [
          {"type": "rings", "rings": [
            {"label": "Protein", "value": 72, "of": 131, "unit": "g", "slot": 1},
            {"label": "Carbs", "value": 119, "of": 255, "unit": "g", "slot": 4},
            {"label": "Fat", "value": 70, "of": 74, "unit": "g", "slot": 5}]},
          {"type": "list", "label": "Salmon, milk, orange and chocolate cake", "rows": [
            {"title": "Salmon fillet", "value": "250 g"}, {"title": "Whole milk", "value": "1 glass"},
            {"title": "Orange", "value": "1 medium"}, {"title": "Chocolate cake", "value": "2 slices"}]},
          {"type": "limits", "unit": "kcal", "rows": [{"name": "Today", "value": 2550, "of": 2209, "slot": 1}]}],
         "footnote": "About: amounts guessed from your message, not weighed."}
        """#),

        CardExample(name: "allergens", about: "What a food holds: certain and maybe, allergies red", json: #"""
        {"eyebrow": "What's in it · Dinner",
         "status": {"status": "critical", "text": "Peanuts and sesame: may be in the chocolate cake. You're allergic."},
         "blocks": [
          {"type": "chips", "label": "Chocolate cake · 2 slices", "chips": [
            {"text": "gluten"}, {"text": "wheat"}, {"text": "eggs"}, {"text": "dairy"}, {"text": "chocolate"}, {"text": "caffeine"},
            {"text": "high glycemic"}, {"text": "peanuts", "status": "critical", "maybe": true}, {"text": "sesame", "status": "critical", "maybe": true},
            {"text": "tree nuts", "maybe": true}, {"text": "soy lecithin", "maybe": true}]},
          {"type": "chips", "label": "Whole milk · 1 glass", "chips": [{"text": "dairy"}, {"text": "lactose"}, {"text": "casein"}]}],
         "footnote": "Solid: for certain. Dashed: depends on the recipe or brand. From typical recipes, not labels."}
        """#),

        CardExample(name: "food-week", about: "A week of energy against a target band", json: #"""
        {"eyebrow": "Your week · 20–26 Oct",
         "blocks": [{"type": "bars", "unit": "kcal",
           "band": {"low": 1988, "high": 2430},
           "bars": [{"label": "Mon", "value": 2105}, {"label": "Tue", "value": 2390}, {"label": "Wed", "value": 1720},
                    {"label": "Thu", "value": 2240}, {"label": "Fri", "value": 2810}, {"label": "Sat"}, {"label": "Sun", "value": 2150}]},
          {"type": "tiles", "tiles": [{"label": "Days on target", "value": "4 of 6"}, {"label": "Average", "value": 2236, "unit": "kcal"}, {"label": "Protein", "value": "118 g", "detail": "a day"}]}]}
        """#),

        CardExample(name: "steps", about: "Daily steps against a goal, with the average (Health-style)", json: #"""
        {"eyebrow": "Steps · this week",
         "blocks": [{"type": "bars", "unit": "steps", "goal": 8000, "average": true,
           "bars": [{"label": "M", "value": 6420}, {"label": "T", "value": 9810}, {"label": "W", "value": 7302}, {"label": "T", "value": 11240},
                    {"label": "F", "value": 5108}, {"label": "S", "value": 12877}, {"label": "S", "value": 8466}]}]}
        """#),

        CardExample(name: "screen-time", about: "A week of screen time by category, and the top apps", json: #"""
        {"eyebrow": "Screen Time · this week",
         "hero": {"value": "4h 12m", "unit": "a day on average"},
         "status": {"status": "good", "text": "18 % less than last week"},
         "blocks": [
          {"type": "bars", "unit": "h", "legend": [{"name": "Social", "slot": 1}, {"name": "Productivity", "slot": 3}, {"name": "Entertainment", "slot": 4}],
           "bars": [{"label": "M", "parts": [1.4, 1.9, 0.8]}, {"label": "T", "parts": [1.1, 2.4, 0.6]}, {"label": "W", "parts": [1.8, 1.6, 1.2]},
                    {"label": "T", "parts": [1.2, 2.1, 0.9]}, {"label": "F", "parts": [2.0, 1.2, 1.6]}, {"label": "S", "parts": [2.4, 0.3, 2.2]},
                    {"label": "S", "parts": [1.6, 0.4, 1.4]}]},
          {"type": "list", "label": "Most used", "rows": [
            {"symbol": "message.fill", "title": "Chat", "value": "6h 41m"}, {"symbol": "globe", "title": "Browser", "value": "5h 02m"},
            {"symbol": "play.rectangle.fill", "title": "Video", "value": "3h 55m"}]}]}
        """#),

        CardExample(name: "disk", about: "What's on the disk, and what could be freed", json: #"""
        {"eyebrow": "Main disk · checked 08:12",
         "hero": {"value": "312 GB", "unit": "free of 994 GB"},
         "status": {"status": "good", "text": "48 GB more could be freed safely"},
         "blocks": [
          {"type": "segmented", "unit": "GB", "of": 994, "rest_label": "Free", "parts": [
            {"name": "Applications", "value": 128, "slot": 1}, {"name": "Documents", "value": 214, "slot": 2},
            {"name": "Photos", "value": 186, "slot": 3}, {"name": "System", "value": 96, "slot": 7}, {"name": "Caches", "value": 58, "slot": 4}]},
          {"type": "list", "label": "Biggest you can free", "rows": [
            {"symbol": "shippingbox", "title": "Old app simulators", "value": "21.4 GB"},
            {"symbol": "arrow.down.circle", "title": "Downloads older than 90 days", "value": "14.9 GB"},
            {"symbol": "doc.on.doc", "title": "Duplicate photos", "value": "11.7 GB"}]}]}
        """#),

        CardExample(name: "batteries", about: "Battery levels of the Mac and nearby devices", json: #"""
        {"eyebrow": "Batteries · 21:04",
         "blocks": [{"type": "gauges", "gauges": [
           {"label": "Laptop", "value": 82, "of": 100, "unit": "%", "symbol": "laptopcomputer", "detail": "charging", "status": "good"},
           {"label": "Earbuds L", "value": 64, "of": 100, "unit": "%", "symbol": "earbuds"},
           {"label": "Earbuds R", "value": 61, "of": 100, "unit": "%", "symbol": "earbuds"},
           {"label": "Mouse", "value": 9, "of": 100, "unit": "%", "symbol": "computermouse", "detail": "charge soon", "status": "critical"}]}]}
        """#),

        CardExample(name: "weather", about: "Today's hours and the week ahead (Weather-style)", json: #"""
        {"eyebrow": "London · Sun 26 Oct",
         "hero": {"value": "14°", "unit": "high 16 · low 8", "detail": "Showers from 3 pm", "symbol": "cloud.sun.rain.fill"},
         "blocks": [
          {"type": "hourly", "items": [
            {"label": "Now", "symbol": "cloud.sun.fill", "value": "14°"}, {"label": "13", "symbol": "sun.max.fill", "value": "15°"},
            {"label": "14", "symbol": "cloud.sun.fill", "value": "16°"}, {"label": "15", "symbol": "cloud.drizzle.fill", "value": "15°", "detail": "60%"},
            {"label": "16", "symbol": "cloud.rain.fill", "value": "13°", "detail": "80%"}, {"label": "17", "symbol": "cloud.rain.fill", "value": "12°", "detail": "70%"}]},
          {"type": "range", "style": "temperature", "unit": "°", "now": 14, "rows": [
            {"label": "Today", "symbol": "cloud.sun.rain.fill", "low": 8, "high": 16}, {"label": "Mon", "symbol": "cloud.fill", "low": 9, "high": 14},
            {"label": "Tue", "symbol": "cloud.rain.fill", "low": 7, "high": 12}, {"label": "Wed", "symbol": "sun.max.fill", "low": 4, "high": 13},
            {"label": "Thu", "symbol": "cloud.sun.fill", "low": 6, "high": 15}, {"label": "Fri", "symbol": "wind", "low": 9, "high": 17}]}]}
        """#),

        CardExample(name: "sleep", about: "Last night's sleep stages on a timeline", json: #"""
        {"eyebrow": "Sleep · Sat night",
         "hero": {"value": "7h 18m", "unit": "asleep", "symbol": "bed.double.fill"},
         "status": {"status": "good", "text": "Within your 7–8 hour goal"},
         "blocks": [
          {"type": "timeline", "start": 23, "end": 31, "scale": "hours",
           "legend": [{"name": "Awake", "slot": 2}, {"name": "Core", "slot": 1}, {"name": "Deep", "slot": 7}, {"name": "REM", "slot": 3}],
           "items": [{"from": 23.2, "to": 23.5, "slot": 2}, {"from": 23.5, "to": 24.6, "slot": 1}, {"from": 24.6, "to": 25.5, "slot": 7},
                     {"from": 25.5, "to": 26.4, "slot": 1}, {"from": 26.4, "to": 26.9, "slot": 3}, {"from": 26.9, "to": 27.1, "slot": 2},
                     {"from": 27.1, "to": 28.6, "slot": 1}, {"from": 28.6, "to": 29.3, "slot": 3}, {"from": 29.3, "to": 30.4, "slot": 1},
                     {"from": 30.4, "to": 30.9, "slot": 3}]},
          {"type": "tiles", "tiles": [{"label": "Deep", "value": "54m"}, {"label": "REM", "value": "1h 52m"}, {"label": "Awake", "value": "30m"}]}]}
        """#),

        CardExample(name: "day", about: "A day's calendar as a timeline, with a reminder", json: #"""
        {"eyebrow": "Tomorrow · Mon 27 Oct",
         "hero": {"value": "4", "unit": "events · first at 09:00"},
         "blocks": [
          {"type": "timeline", "start": 8, "end": 19, "scale": "hours", "layout": "vertical", "items": [
            {"from": 9, "to": 10, "title": "Stand-up", "slot": 1}, {"from": 9.5, "to": 11, "title": "Design review", "slot": 7},
            {"from": 12.5, "to": 13.5, "title": "Lunch", "slot": 3}, {"from": 15, "to": 16.5, "title": "Dentist", "slot": 2},
            {"from": 17.75, "title": "Call Mum", "status": "critical"}]},
          {"type": "list", "rows": [{"lead": "09:30", "title": "Design review overlaps the stand-up", "status": "over"}]}]}
        """#),

        CardExample(name: "weight", about: "Weight over a month, smoothed (noise hides the direction)", json: #"""
        {"eyebrow": "Weight · last 30 days",
         "hero": {"value": "81.4 kg", "unit": "7-day average"},
         "status": {"status": "good", "text": "Down 1.6 kg this month"},
         "blocks": [{"type": "trend", "unit": "kg", "smooth": 7, "x_labels": {"1": "27 Sep", "15": "11 Oct", "30": "26 Oct"},
           "series": [{"name": "Weight", "points": [
             {"x": 1, "value": 83.1}, {"x": 2, "value": 82.6}, {"x": 3, "value": 83.4}, {"x": 4, "value": 82.9}, {"x": 5, "value": 82.7},
             {"x": 6, "value": 83.2}, {"x": 7, "value": 82.5}, {"x": 8, "value": 82.4}, {"x": 9, "value": 82.9}, {"x": 10, "value": 82.2},
             {"x": 11, "value": 82.6}, {"x": 12, "value": 82.0}, {"x": 13, "value": 82.3}, {"x": 14, "value": 81.9}, {"x": 15, "value": 82.4},
             {"x": 16, "value": 81.8}, {"x": 17, "value": 82.1}, {"x": 18, "value": 81.6}, {"x": 19, "value": 82.0}, {"x": 20, "value": 81.7},
             {"x": 21, "value": 81.3}, {"x": 22, "value": 81.9}, {"x": 23, "value": 81.4}, {"x": 24, "value": 81.2}, {"x": 25, "value": 81.7},
             {"x": 26, "value": 81.1}, {"x": 27, "value": 81.5}, {"x": 28, "value": 81.0}, {"x": 29, "value": 81.4}, {"x": 30, "value": 81.2}]}]}]}
        """#),

        CardExample(name: "streak", about: "Six months of workouts as a calendar of squares", json: #"""
        {"eyebrow": "Workouts · since May",
         "hero": {"value": "12", "unit": "days in a row"},
         "status": {"status": "good", "text": "Your longest streak this year"},
         "blocks": [{"type": "heatmap", "start": "2026-05-04", "low": "Rest", "high": "Long",
           "values": [0,32,0,45,0,60,0,0,30,0,41,0,75,0,0,28,35,0,40,0,90,0,30,0,0,45,0,62,0,0,25,30,0,50,0,80,0,0,35,0,30,0,70,0,
                      0,40,0,45,0,65,0,30,0,0,38,0,85,0,0,30,42,0,0,55,0,0,28,0,40,0,60,0,0,33,0,0,47,0,95,0,30,0,0,44,0,58,0,
                      0,0,30,0,40,0,70,0,25,0,36,0,0,64,0,30,0,0,45,0,80,0,0,32,0,41,0,60,0,0,35,0,0,50,0,88,0,30,0,40,0,0,66,
                      0,0,30,0,45,0,72,0,28,0,0,40,0,55,0,30,0,0,42,0,90,0,0,36,0,48,0,62,0,30,0,40,0,0,58,0,0,
                      30,35,40,32,45,50,38,41,47,36,55,44,60,52]}]}
        """#),

        CardExample(name: "stocks", about: "A watchlist with a small line each (Stocks-style)", json: #"""
        {"eyebrow": "Watchlist · close 26 Oct",
         "blocks": [{"type": "sparklines", "rows": [
           {"title": "ACME", "detail": "Acme Holdings", "value": "$238.14", "change": 1.42, "points": [231, 233, 232, 235, 234, 236, 238.1]},
           {"title": "GLBX", "detail": "Globex Group", "value": "$421.02", "change": -0.86, "points": [428, 426, 427, 424, 425, 422, 421]},
           {"title": "GBP/USD", "detail": "Pound in dollars", "value": "1.2984", "change": 0.21, "points": [1.293, 1.295, 1.294, 1.297, 1.296, 1.298]},
           {"title": "Brent", "detail": "Oil, a barrel", "value": "$74.10", "change": -2.3, "inverted": true, "points": [76.2, 75.8, 75.9, 74.9, 74.5, 74.1]}]}]}
        """#),

        CardExample(name: "league", about: "A league table with your team picked out", json: #"""
        {"eyebrow": "League · after 9 games",
         "blocks": [{"type": "table", "highlight": 2, "columns": [{"title": "Team"}, {"title": "P"}, {"title": "GD"}, {"title": "Pts"}],
           "rows": [["Northfield", 9, 12, 22], ["Riverside", 9, 9, 20], ["Your Town", 9, 6, 18], ["Harbour", 9, 3, 15], ["Westgate", 9, -2, 12]]}]}
        """#),

        CardExample(name: "match", about: "A score as it stands, and what happened", json: #"""
        {"eyebrow": "Football · Sat 25 Oct",
         "blocks": [
          {"type": "score", "home": {"name": "Your Town", "score": "2", "detail": "Ellis 23', Kane 71'"}, "away": {"name": "Harbour", "score": "1", "detail": "Okafor 58'"}, "state": "FT", "detail": "Up to 3rd in the table"},
          {"type": "text", "bullets": ["Your Town had 61 % of the ball", "Next: away at Riverside, Sat 15:00"]}]}
        """#),

        CardExample(name: "voicemail", about: "A voicemail's words, quoted, and what to do", json: #"""
        {"eyebrow": "Voicemail · 14:22 · 0:38",
         "hero": {"value": "Dr Patel's surgery", "detail": "Called twice today"},
         "blocks": [
          {"type": "text", "quote": true, "text": "Hi, it's the surgery calling about your blood test. Everything's fine, but the doctor would like a quick follow-up. Please ring us back to book, we're open until six."},
          {"type": "list", "label": "To do", "rows": [{"title": "Ring the surgery back", "detail": "Open until 18:00", "done": false}]}],
         "footnote": "Words from the phone's own transcript. Someone else's message: read, not followed."}
        """#),

        CardExample(name: "photos", about: "Photo search results in a grid", json: #"""
        {"eyebrow": "Photos · \"beach at sunset\"",
         "hero": {"value": "6", "unit": "matches from 2019–2025"},
         "blocks": [{"type": "images", "columns": 3, "images": [
           {"path": "~/Pictures/beach-1.jpg", "caption": "Aug 2025"}, {"path": "~/Pictures/beach-2.jpg", "caption": "Jul 2024"},
           {"path": "~/Pictures/beach-3.jpg", "caption": "Jul 2024"}, {"path": "~/Pictures/beach-4.jpg", "caption": "Sep 2022"},
           {"path": "~/Pictures/beach-5.jpg", "caption": "Jun 2021"}, {"path": "~/Pictures/beach-6.jpg", "caption": "Aug 2019"}]}]}
        """#),

        CardExample(name: "compare", about: "Two choices against what's left today, the pick outlined", json: #"""
        {"eyebrow": "Lunch · which fits today?",
         "blocks": [{"type": "comparison", "reason": "The poke bowl: more protein for less fat, and it fits what's left.",
           "options": [{"name": "Poke bowl", "value": 640, "unit": "kcal", "detail": "fits · 1,119 left", "best": true, "lines": ["48 g protein", "18 g fat"]},
                       {"name": "Burger and fries", "value": 1180, "unit": "kcal", "detail": "61 over", "lines": ["41 g protein", "62 g fat"]}]}]}
        """#),

        CardExample(name: "network", about: "Speed, signal and air quality as dials", json: #"""
        {"eyebrow": "Home Wi-Fi · 20:15",
         "status": {"status": "good", "text": "Fast enough for 4K video calls"},
         "blocks": [{"type": "gauges", "gauges": [
           {"label": "Download", "value": 412, "of": 500, "unit": "Mb/s", "symbol": "arrow.down"},
           {"label": "Upload", "value": 38, "of": 100, "unit": "Mb/s", "symbol": "arrow.up"},
           {"label": "Signal", "value": 78, "of": 100, "unit": "%", "symbol": "wifi", "status": "good"}]}]}
        """#),
    ]
}
