using { /Verse.org/Simulation/Tags }

pad_info<public> := struct<concrete>:
    Cost<public> : int = 0
    Name<public> : string = ""

pad_config<public> := class<concrete>:
    GeneratorPad<public> : pad_info = pad_info{Cost := 100, Name := "Gold Generator"}
    WingPads<public>     : []pad_info = array:
        pad_info{Cost := 200, Name := "Mansion · Ground Floor"}
        pad_info{Cost := 300, Name := "Mansion · Upper Floor"}
        pad_info{Cost := 800, Name := "Observatory · Base"}
        pad_info{Cost := 1000, Name := "Observatory · Tower"}

StartingGold<public>      : int = 100
IncomePerTick<public>     : int = 50
IncomeTickSeconds<public> : float = 1.0

PadLabel<public><localizes>(Name : string, Cost : int) : message = "{Name}\n{Cost} Gold"
BlankLabel<public><localizes> : message = ""

pad_generator<public> := class(tag){}
pad_wing_1<public> := class(tag){}
pad_wing_2<public> := class(tag){}
pad_wing_3<public> := class(tag){}
pad_wing_4<public> := class(tag){}
