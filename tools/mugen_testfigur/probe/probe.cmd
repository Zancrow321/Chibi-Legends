; Probe - Befehle (eigene Testfigur)
[Remap]
x = x
y = y
z = z
a = a
b = b
c = c
s = s

[Defaults]
command.time = 15
command.buffer.time = 1

[Command]
name = "Funkenstoss"
command = ~D, DF, F, x
time = 15

[Command]
name = "x"
command = x
time = 1

[Command]
name = "y"
command = y
time = 1

[Command]
name = "a"
command = a
time = 1

[Command]
name = "holdfwd"
command = /$F
time = 1

[Command]
name = "holddown"
command = /$D
time = 1

[Statedef -1]

[State -1, Funkenstoss]
type = ChangeState
value = 1000
triggerall = command = "Funkenstoss"
trigger1 = statetype != A
trigger1 = ctrl

[State -1, Hoher Tritt]
type = ChangeState
value = 220
triggerall = command = "y"
triggerall = command = "holdfwd"
trigger1 = statetype = S
trigger1 = ctrl

[State -1, Leichter Schlag]
type = ChangeState
value = 200
triggerall = command = "x"
triggerall = command != "holddown"
trigger1 = statetype = S
trigger1 = ctrl

[State -1, Schwerer Schlag]
type = ChangeState
value = 210
triggerall = command = "y"
trigger1 = statetype = S
trigger1 = ctrl

[State -1, Feger]
type = ChangeState
value = 230
triggerall = command = "a"
triggerall = command = "holddown"
trigger1 = statetype = C
trigger1 = ctrl

[State -1, Lufttritt]
type = ChangeState
value = 600
triggerall = command = "x"
trigger1 = statetype = A
trigger1 = ctrl
