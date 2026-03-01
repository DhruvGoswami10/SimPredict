import TipKit

struct WelcomeSwipeTip: Tip {
    var title: Text {
        Text("Swipe to Explore")
    }
    var message: Text? {
        Text("Swipe through the pages to learn about your mission as a Race Strategist.")
    }
    var image: Image? {
        Image(systemName: "hand.draw.fill")
    }
}

struct ModelSelectionTip: Tip {
    var title: Text {
        Text("Choose Your Model")
    }
    var message: Text? {
        Text("Tap any model to see an interactive visualization of how it works.")
    }
    var image: Image? {
        Image(systemName: "cpu")
    }
}

struct DataPlaygroundTip: Tip {
    var title: Text {
        Text("Experiment with Data")
    }
    var message: Text? {
        Text("Adjust driver stats and watch how predictions change in real-time.")
    }
    var image: Image? {
        Image(systemName: "slider.horizontal.3")
    }
}

struct NoiseExperimentTip: Tip {
    var title: Text {
        Text("Try Adding Noise")
    }
    var message: Text? {
        Text("Add irrelevant data like 'Favorite Color' to see how it confuses the model.")
    }
    var image: Image? {
        Image(systemName: "waveform.path")
    }
}

struct TrackSelectionTip: Tip {
    var title: Text {
        Text("Pick Your Circuit")
    }
    var message: Text? {
        Text("Different tracks favor different driver strengths. Choose wisely!")
    }
    var image: Image? {
        Image(systemName: "flag.checkered")
    }
}

struct BuildModelTip: Tip {
    var title: Text {
        Text("Design Your Own Model")
    }
    var message: Text? {
        Text("Set feature weights to create a custom ML model and see how it compares.")
    }
    var image: Image? {
        Image(systemName: "wrench.and.screwdriver.fill")
    }
}

struct PredictLaunchTip: Tip {
    var title: Text {
        Text("Ready To Launch")
    }
    var message: Text? {
        Text("Review your setup, then tap Predict & Race to validate your model in simulation.")
    }
    var image: Image? {
        Image(systemName: "flag.checkered")
    }
}
