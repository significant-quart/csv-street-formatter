local fs = require("fs")
local json = require("json")
local path = require("pathjoin")
local timer = require("timer")


local F = string.format


local ROUTE_ID
local OUT_NAME = os.date("!%d-%m-%y @ %H-%M-%S.csv", os.time())
local ZONE_SEP = ",,,\n,,,"

local CSV_FILENAME_PATTERN = ".*%.csv$"
local ROUTE_FILENAME_PATTERN = ".*%.txt$"
local ROUTES_PATTERN = "([^\r\n]+)"
local ROUTE_ADDR_PATTERN = "%s*([^,]+)"
local ZONE_PATTERN = "^%a$"
local ORDER_PATTERN = " %[dsc%]$"
local ROW_PATTERN = "([^\r\n]+)"
local COL_PATTERN = "([^,]*)"
local EMPTY_ADDR_PATTERN = "^%d+$"
local ADDR_GETTER_PATTERN = "^(%d+)[a-z]?"


local routes = {}
local config


local function init()
    config = fs.readFileSync("./config.json")
    if not config then error("\"config.json\" not found!") end
    config = json.decode(config)
    if not config then error("Could not parse \"config.json\"!") end

    if not fs.existsSync(config.DATA_IN) then error(F("DATA_IN not found! Ensure directory \"%s\" exists!", config.DATA_IN)) end
    if not fs.existsSync(config.DATA_OUT) then error(F("DATA_OUT not found! Ensure directory \"%s\" exists!", config.DATA_OUT)) end
    if not fs.existsSync(config.ROUTES_DIR) then error(F("ROUTES_DIR not found! Ensure directory \"%s\" exists!", config.ROUTES_DIR)) end

    for name, _ in fs.scandirSync(config.ROUTES_DIR) do
        if name:match(ROUTE_FILENAME_PATTERN) then
            table.insert(routes, name)
        end
    end
end

local function awaitCoroutine(co)
    while coroutine.status(co) ~= "dead" do
        timer.sleep(50)
    end
end

local function main()
    local buffer, newLine, colPos, zone, streets
    local rawData, streetData = {}, {}

    local function isColumnBlacklisted()
        for i, col in ipairs(config.BLACKLISTED_COLUMNS) do
            if ((col * 2) - 1) == colPos then
                return true
            end
        end

        return false
    end

    buffer = fs.readFileSync(path.pathJoin(config.ROUTES_DIR, routes[ROUTE_ID]))
    for street in buffer:gmatch(ROUTES_PATTERN) do
        streets = {}

        if street:match(ZONE_PATTERN) then
            zone = street
        elseif street ~= "\r" then
            street = street:lower()

            for str in street:gmatch(ROUTE_ADDR_PATTERN) do
                str = str:gsub(ORDER_PATTERN, "")
                table.insert(streets, str)
            end

            table.insert(streetData, {
                ["streets"] = streets,
                ["zone"] = zone,
                ["asc"] = (street:match(ORDER_PATTERN) == nil),
                ["addresses"] = {}
            })
        end
    end

    table.insert(streetData, {
        ["addresses"] = {}
    })

    for name, fType in fs.scandirSync(config.DATA_IN) do
        p(F("Reading %s...", name))

        if name:match(CSV_FILENAME_PATTERN) then
            buffer = fs.readFileSync(path.pathJoin(config.DATA_IN, name))
            if not buffer then
                p(F("Failed to read file \"%s\"! Is the file read protected?", name))

                goto continue
            end

            table.insert(rawData, buffer)

            ::continue::
        end
    end

    buffer = table.concat(rawData, "\n")

    for line in buffer:gmatch(ROW_PATTERN) do
        newLine = {}
        colPos = 1

        for col in line:gmatch(COL_PATTERN) do
            if isColumnBlacklisted() or #col == 0 then
                goto nextCol
            end

            table.insert(newLine, col)

            ::nextCol::

            colPos = colPos + 1
        end

        if #newLine == 0 then
            goto nextLine
        end

        if newLine[1]:lower():match(EMPTY_ADDR_PATTERN) then
            table.insert(streetData[#streetData].addresses, newLine)
        else
            for i, t in ipairs(streetData) do
                if t.streets ~= nil then
                    for j, street in ipairs(t.streets) do
                        if newLine[1]:lower():find(street) then
                            table.insert(t.addresses, newLine)
    
                            goto nextLine
                        end
                    end
                else
                    table.insert(t.addresses, newLine)
                end
            end
        end

        ::nextLine::
    end

    local out = {}

    for j, street in ipairs(streetData) do
        table.sort(street.addresses, function(a, b)
            if j < #streetData then
                a, b = tonumber(a[1]:match(ADDR_GETTER_PATTERN)), tonumber(b[1]:match(ADDR_GETTER_PATTERN))

                if a == nil or b == nil then
                    return false
                end

                if street.asc then
                    return a < b
                end

                return a > b
            else
                local aArea, aSector = a[2]:match("%a%a(%d+)%s?([%a%d]+)")
                local bArea, bSector = b[2]:match("%a%a(%d+)%s?([%a%d]+)")
                aArea, bArea = tonumber(aArea), tonumber(bArea)

                if aArea == bArea then
                    return aSector < bSector
                end

                return aArea < bArea
            end
        end)

        if j > 1 then
            if street.zone ~= streetData[j - 1].zone and out[#out] ~= ZONE_SEP then
                table.insert(out, ZONE_SEP)
            end
        end

        for k, address in ipairs(street.addresses) do
            table.insert(out, table.concat(address, ","))
        end
    end

    fs.writeFileSync(path.pathJoin(config.DATA_OUT, OUT_NAME), table.concat(out, "\n"))

    p(F("Finished and wrote to %s!", OUT_NAME))
end


return require('luvit')(function (...)
    init()

    local co, cb
    local function userinput()
        process.stdin:on("data", function(data)
            data = data:match("([^\r\n]+)")

            cb(data)

            coroutine.resume(co)
        end)

        return coroutine.yield()
    end

    p("Enter the name of the output CSV:")
    co = coroutine.create(userinput)
    cb = function(data)
        if data ~= nil and #data > 0 then
            if not data:match(CSV_FILENAME_PATTERN) then
                data = data .. ".csv"
            end

            OUT_NAME = data
        end
    end
    coroutine.resume(co)

    awaitCoroutine(co)

    p("Enter the ID of the route:")
    for i, route in pairs(routes) do
        p(F("[%d] %s", i, route))
    end

    co = coroutine.create(userinput)
    cb = function(data)
        data = tonumber(data)
        if data == nil or routes[data] == nil then
            error("Invalid route ID!")
        end

        ROUTE_ID = data
    end
    coroutine.resume(co)

    awaitCoroutine(co)

    process.stdin.handle:close()

    main()
end, ...)