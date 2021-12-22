extends Object
class_name CollisionLayerConstants

const Obstacles_bit = 0
const Player_bit    = 2
const Floor_bit     = 3
const Saber_bit     = 4
const Bombs_bit     = 5
const LeftNote_bit  = 9
const RightNote_bit = 10

const Obstables_mask = (1 << Obstacles_bit)
const Player_mask    = (1 << Player_bit)
const Floor_mask     = (1 << Floor_bit)
const Saber_mask     = (1 << Saber_bit)
const Bombs_mask     = (1 << Bombs_bit)
const LeftNote_mask  = (1 << LeftNote_bit)
const RightNote_mask = (1 << RightNote_bit)
const AllNotes_mask  = (LeftNote_mask | RightNote_mask)
