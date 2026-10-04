local items = {
    { Id = "medkit", Category = "Supplies", Name = "Medkit", Price = 30, MaxStock = 5, Color = { 223, 59, 59 }, Description = "Heal 35 HP once. Equip and click during a round." },
    { Id = "soda", Category = "Supplies", Name = "Bloxy Soda", Price = 20, MaxStock = 5, Color = { 229, 156, 43 }, Description = "Run faster for 8 seconds. One use per round." },
    { Id = "spring", Category = "Supplies", Name = "Jump Spring", Price = 25, MaxStock = 5, Color = { 54, 162, 220 }, Description = "Jump higher for 8 seconds. One use per round." },
    { Id = "shield", Category = "Supplies", Name = "Shield Capsule", Price = 45, MaxStock = 5, Color = { 91, 177, 90 }, Description = "Block damage for 5 seconds. Falls still eliminate you." },
}
local byId = {}
for _, item in ipairs(items) do byId[item.Id] = item end
return table.freeze({ Items = items, ById = byId, Categories = { "Supplies" } })
