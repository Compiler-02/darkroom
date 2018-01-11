darkroom.optimize={}
-- 两个减号时单行注释
--[[
这是多行注释的意思
--]]
-- I don't trust these optimizations, so make sure we print out exactly what we're doing
darkroom.optimize.verbose = true

-- lua doesn't iterate over keys in a consistant order
darkroom.optimize._keyOrderCache = {}
-- {}指关联数组，索引可以是数字或者字符串，这里构造一个空表
function darkroom.optimize.keyOrder(ast)
  assert(type(ast.kind)=="string")

  local mt = getmetatable(ast)
  if darkroom.optimize._keyOrderCache[mt]==nil then
    darkroom.optimize._keyOrderCache[mt] = setmetatable({}, {__mode="k"})
  end

  local aCnt = 0
  for k,v in pairs(ast) do
    aCnt = aCnt+1
  end

  if darkroom.optimize._keyOrderCache[mt][ast.kind]==nil then
    darkroom.optimize._keyOrderCache[mt][ast.kind]={}
  end

  if darkroom.optimize._keyOrderCache[mt][ast.kind][aCnt] == nil then
    darkroom.optimize._keyOrderCache[mt][ast.kind][aCnt] = {}

    for k,_ in pairs(ast) do
      table.insert(darkroom.optimize._keyOrderCache[mt][ast.kind][aCnt],k)
    end
  end

  return darkroom.optimize._keyOrderCache[mt][ast.kind][aCnt]
end

function darkroom.optimize.CSEHash(ast)

  local hash = ""
  
  local keyOrder = darkroom.optimize.keyOrder(ast)

  for _,k in ipairs(keyOrder) do

    if ast[k]==nil then
      print(ast.kind,k)
      for k,v in pairs(ast) do print(k,v) end
      print("ORDER")
      for k,v in ipairs(keyOrder) do print(k,v) end
      assert(false)
    end

    hash = hash..tostring(ast[k])
  end

  return hash
end

function darkroom.optimize.CSE(inast, hashRepo)
  assert(type(hashRepo)=="table")

  if darkroom.verbose or darkroom.printstage then 
    print("run CSE") 
    print(debug.traceback())
  end

  local outast = inast:S("*"):process(function(ast)
    local hash = darkroom.optimize.CSEHash(ast)
    --print("hash",hash)

    if hashRepo[hash]~=nil then
      -- potentially we have a match, make sure our hash isn't messed up
      assert(ast:equals(hashRepo[hash]))
      --print("Matchfound")
      return hashRepo[hash]
    end

    -- no CSE found. save this one.
    hashRepo[hash] = ast

    return ast
  end)

  return outast
end

function darkroom.optimize.optimizeMath(ast)

  -- remove identity ops. ie x+0, x*1
  ast = ast:S("binop"):process(function(ast)
    local lhs = darkroom.optimize.constantFoldCasts(ast.lhs)
    local rhs = darkroom.optimize.constantFoldCasts(ast.rhs)

    if ast.op=="+" and lhs.kind=="value" and darkroom.optimize.isZero(lhs.value) then
      return ast.rhs
    -- [1]********对加法，如果一个值为零，就直接返回另一个值******
    elseif ast.op=="+" and rhs.kind=="value" and darkroom.optimize.isZero(rhs.value) then
      return ast.lhs
    end

    return ast end) --括号内定义了一个函数

  -- turn mult/div by power of two into a shift
  -- 乘除对二的幂次进行时，转换为移位运算
  -- 这个优化在主要的optimize函数中进行
--  ast = ast:S("binop"):process(function(ast)
--    if ast.op=="/" and ast.rhs.kind=="value" and ast.rhs.value and false
--  end)

  -- take (a+b)/3 -> a/3+b/3
  -- this can be good for conv engine (pushes more stuff in map operator)
  -- 对(a+b)/3 改造为 a/3+b/3 ， 利用了卷积引擎，充分填充map算子
  ast = ast:S("binop"):process(function(ast)
    if ast.op=="/" and 
       ast.rhs.kind=="value" and 
       ast.lhs.kind=="binop" and 
       ast.lhs.op=="+" then
      print("DISTRIBUTE")
      local lhsdivop = darkroom.ast.binop("/",ast.lhs.lhs,ast.rhs)
      local rhsdivop = darkroom.ast.binop("/",ast.lhs.rhs,ast.rhs)
      local resast=darkroom.ast.binop("+",lhsdivop,rhsdivop)
      return darkroom._toTypedAST(resast)
    end
    return ast
  end)

  return ast	 
end

function darkroom.optimize.performOp(op, lhs, rhs)
  if op=="+" then
    return lhs+rhs
  elseif op=="/" then
    return lhs/rhs
  elseif op=="*" then
    return lhs*rhs
  elseif op=="==" then
    return lhs==rhs
  elseif op=="-" then
    return lhs - rhs
  elseif op=="<<" then
    return lhs * math.pow(2,rhs)
  elseif op==">>" then
    return lhs / math.pow(2,rhs)
  end

  print(op)

  assert(false)
end

function darkroom.optimize.constantFold(ast)
--常量折叠
  ast = ast:S("binop"):process(function(ast)
    if ast.lhs.kind=="value" and ast.rhs.kind=="value" then
      local outval = darkroom.optimize.performOp(ast.op, ast.lhs.value, ast.rhs.value)
      if darkroom.optimize.verbose then
        print("Constant fold: "..ast.lhs.value.." "..ast.op.." "..ast.rhs.value,outval)
      end

--      return darkroom.ast.value(outval, darkroom.type.valueToType(outval))
      local res = {kind="value", value=outval, type=ast.type}
      return darkroom.internalIR.new(res):copyMetadataFrom(ast)
    end

    return ast
  end)

  return ast
end

function darkroom.optimize.constantFoldCasts(ast)
  -- ???
  -- do casts of constants
  ast = ast:S("cast"):process(function(ast)
    if ast.expr.kind=="value" then
      if darkroom.type.isArray(ast.type) and 
         darkroom.type.isNumber(ast.type.over) and
	        darkroom.type.isArray(ast.expr.type)==false and
	            darkroom.type.isNumber(ast.expr.type) then
	--[[
    如果是cast操作，也就是[uint8[3]](inputImage(x,y)*0.9)这样的
    ast.expr对应inputImage(x,y)*0.9
    ast.type对应要转换成的类型，如果要转换成的类型是数组
    而且数组的长度已经可以获得（Number）
    且被转换的不是数组而是数字
    则直接复制到转换类型数组的每一项
    ]]--
	    local newval = {}
	    for i=1,darkroom.type.arrayLength(ast.type) do newval[i] = ast.expr.value end
        
	    local oast = darkroom.ast.value(newval, ast.type)
	    oast.name = ast.name
	    return oast
      end
    end

    return ast
  end)

  return ast
end

function darkroom.optimize.isZero(val)
    --判断是否为零（对数组和单个数都有效）
  if type(val)=="number" and val==0 then 
    return true 
  end

  if type(val)=="number" and val~=0 then 
    return false
  end

  if type(val)=="table" then
    print("IZ")
    print(to_string(val))
    for k,v in ipairs(val) do if v~=0 then return false end end
    print("VEC IS ZERO")
    return true
  end

  assert(false)
end

-- ast should be a typed ast
function darkroom.optimize.optimize(ast, options)
  assert(darkroom.typedAST.isTypedAST(ast))
  assert(type(options)=="table")

  if options.printstage then
    print("Optimize")
  end
  
  -- *******cast转换**********
  -- remove noop casts
  -- 要转换的类型就是本身类型，不进行转换
  ast = ast:S("cast"):process(function(ast) if ast.type==ast.expr.type then return ast.expr else return ast end end)

  -- we don't support non-int32 constants, but we can do the cast at compile time...
  ast = ast:S("cast"):process(
    function(ast) 
      if ast.expr.kind=="value" then 
        local n = ast.expr:shallowcopy()
        n.type = ast.type

        local vi, vf = math.modf(ast.expr.value)
        -- modf作用：返回整数和小数部分，下面检测小数部分
        -- 要为0才能进行转换，也就是只能对整数进行转换
        -- only do the optimization if the value isn't modified by it
        if (vf==0 and n.type==darkroom.type.uint(8) and ast.expr.value >=0 and ast.expr.value <256) or
          (vf==0 and n.type==darkroom.type.uint(16) and ast.expr.value >=0 and ast.expr.value < math.pow(2,16)) or
          (vf==0 and n.type==darkroom.type.uint(32) and ast.expr.value >=0 and ast.expr.value < math.pow(2,32)) then
          return darkroom.typedAST.new(n):copyMetadataFrom(ast.expr)
        end
      end
    end)

  if options.fastmath then
    -- 常量折叠优化
    ast = darkroom.optimize.constantFold(ast)

    -- getting rid of unnecessary mults/ divides is important for conv engine
    -- prob doesn't help on cpu though
    -- 卷积中乘除代价大，转为移位运算
    ast = ast:S("binop"):process(
      function(ast) 
        -- 优化除法，如果有一个是可以获得值的立即数
        if ast.op=="/" and ast.rhs.kind=="value" and ast.lhs.kind~="value" and
          (darkroom.type.isUint(ast.lhs.type) or darkroom.type.isInt(ast.lhs.type)) and
          (darkroom.type.isUint(ast.rhs.type) or darkroom.type.isInt(ast.rhs.type)) and
          ast.rhs.value > 0
        then
          
          -- this optimization isn't safe, it won't preserve values
          -- known issue: rounding on negative numbers
          -- (-109) >> 1 = -55
          -- (-109) / 2 = -54 
          -- 但目前有一点小问题，就是移位会对负数取下整，而除法取上整
          local pow2 = math.floor(math.log(ast.rhs.value)/math.log(2))
          -- 除法转移位
          if ast.rhs.value==math.pow(2,pow2) then
            if darkroom.optimize.verbose then
              print("divok",ast.translate1_lhs, ast.translate2_lhs,ast.translate1_rhs, ast.translate2_rhs)
            end

            -- we can turn this into a right shift
            local nn = ast:shallowcopy()
            local nv = {kind="value",value=pow2,type=darkroom.type.uint(32)}
            nv = darkroom.internalIR.new(nv):copyMetadataFrom(ast.rhs)
            nn.rhs = nv
            nn.translate1_rhs = 0
            nn.translate2_rhs = 0
            nn.scale1_rhs = 1
            nn.scale2_rhs = 1


            nn.op=">>"
            local res = darkroom.internalIR.new(nn):copyMetadataFrom(ast)

            if false then -- for debugging
              local cond = {kind="binop",op="==",lhs=ast,rhs=res,type=darkroom.type.bool(),
                            translate1_lhs=0,translate2_lhs=0,scale1_lhs=1,scale2_lhs=1,
                            translate1_rhs=0,translate2_rhs=0,scale1_rhs=1,scale2_rhs=1}
              cond = darkroom.internalIR.new(cond):copyMetadataFrom(ast)
              local asrt = {kind="assert",expr=res,printval=ast.lhs,cond=cond,type=res.type,
                            translate1_expr=0,translate2_expr=0,scale1_expr=1,scale2_expr=1,
                            translate1_cond=0,translate2_cond=0,scale1_cond=1,scale2_cond=1,
                            translate1_printval=0,translate2_printval=0,scale1_printval=1,scale2_printval=1}
              
              darkroom.internalIR.new(asrt):copyMetadataFrom(ast)

              return asrt
            end

            return res
          else
            if darkroom.optimize.verbose then
              print("divfail",ast.rhs.value,ast.translate1_rhs,ast.translate2_rhs,ast:filename(),"line",ast:linenumber())
              print(ast.translate1_lhs, ast.translate2_lhs)
            end
          end
        -- 简化乘法运算
        -- 简化乘1运算
        elseif ast.op=="*" and ast.rhs.kind=="value" and ast.rhs.value==1 then
          return ast.lhs
        elseif ast.op=="*" and ast.lhs.kind=="value" and ast.lhs.value==1 then
          return ast.rhs
        elseif ast.op=="*" and ast.rhs.kind=="value" and ast.rhs.value==0 then
          return ast.rhs --乘0返回0，也就是ast.rhs
        elseif ast.op=="*" and ast.lhs.kind=="value" and ast.lhs.value==0 then
          return ast.lhs
        elseif ast.op=="*" and 
          ((ast.rhs.kind=="value" and ast.lhs.kind~="value" and ast.rhs.value>1) or 
           (ast.lhs.kind=="value" and ast.rhs.kind~="value" and ast.lhs.value>1)) and
          (darkroom.type.isUint(ast.lhs.type) or darkroom.type.isInt(ast.lhs.type)) and
          (darkroom.type.isUint(ast.rhs.type) or darkroom.type.isInt(ast.rhs.type)) then
            --  有一个数可以立即获得值
          --

          local valueOp = ast.rhs
          local otherOp = ast.lhs
          local valueT1 = ast.translate1_rhs
          local valueT2 = ast.translate2_rhs
          if ast.lhs.kind=="value" then
            valueOp = ast.lhs
            otherOp = ast.rhs
            valueT1 = ast.translate1_lhs
            valueT2 = ast.translate2_lhs
          end
            --乘法转移位
          local pow2 = math.floor(math.log(valueOp.value)/math.log(2))

          assert(pow2>0)

          if valueOp.value==math.pow(2,pow2) then
            if darkroom.optimize.verbose then
              print("mulok",valueOp.value,pow2,math.pow(2,pow2),valueOp.value==math.pow(2,pow2))
            end

            -- we can turn this into a left shift
            local nn = ast:shallowcopy()
            local nv = {kind="value",value=pow2,type=darkroom.type.uint(32)}
            nv = darkroom.internalIR.new(nv):copyMetadataFrom(ast.rhs)
            nn.rhs = nv
            nn.lhs = otherOp
            nn.op="<<"

            -- swap the translates
            if ast.lhs.kind=="value" then
              nn.translate1_lhs = nn.translate1_rhs
              nn.translate2_lhs = nn.translate2_rhs
              nn.scale1_lhs = nn.scale1_rhs
              nn.scale2_lhs = nn.scale2_rhs
            end

            nn.translate1_rhs = 0
            nn.translate2_rhs = 0
            nn.scale1_rhs = 1
            nn.scale2_rhs = 1

            local res = darkroom.internalIR.new(nn):copyMetadataFrom(ast)

            if false then
              local cond = {kind="binop",op="==",lhs=ast,rhs=res,type=darkroom.type.bool(),
                            translate1_lhs=0,translate2_lhs=0,scale1_lhs=1,scale2_lhs=1,
                            translate1_rhs=0,translate2_rhs=0,scale1_rhs=1,scale2_rhs=1}
              cond = darkroom.internalIR.new(cond):copyMetadataFrom(ast)
              local asrt = {kind="assert",expr=res,printval=otherOp,cond=cond,type=res.type,
                            translate1_expr=0,translate2_expr=0,scale1_expr=1,scale2_expr=1,
                            translate1_cond=0,translate2_cond=0,scale1_cond=1,scale2_cond=1,
                            translate1_printval=0,translate2_printval=0,scale1_printval=1,scale2_printval=1}
              
              darkroom.internalIR.new(asrt):copyMetadataFrom(ast)
              return asrt
            end

            return res
          else
            if darkroom.optimize.verbose then
              print("mulfail",valueOp.value,valueT1,valueT2,ast:filename(),"line",ast:linenumber())
            end
          end
        elseif ast.op=="*" and  (ast.rhs.kind=="value" or ast.lhs.kind=="value") then
          if darkroom.optimize.verbose then
            print("fastmath FAIL")
          end
        end
      end)
  end
  
  local cseRepo={}
  ast = darkroom.optimize.CSE(ast, cseRepo)

  if options.verbose then
    print("Optimizations Done --------------------------")
  end

  return ast
end
