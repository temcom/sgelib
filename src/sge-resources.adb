with Ada.Calendar; use Ada.Calendar;
with Ada.Calendar.Formatting; use Ada.Calendar.Formatting;
with Ada.Real_Time;
with Ada.Strings; use Ada.Strings;
with Ada.Strings.Equal_Case_Insensitive;
with Ada.Strings.Unbounded.Hash;
with Ada.Containers; use Ada.Containers;
with SGE.Resources; use SGE.Resources.Resource_Lists;
with SGE.Utils; use SGE.Utils; use SGE.Utils.Hash_Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Maps.Constants;

package body SGE.Resources is

   function Contains (Container : Hashed_List; Key : String) return Boolean is
   begin
      return Contains (Container, To_Unbounded_String (Key));
   end Contains;

   overriding function Copy (Source : Hashed_List) return Hashed_List is
   begin
      return (Resource_Lists.Copy (Resource_Lists.Map (Source)) with
      Hash_Value => Source.Hash_Value,
      Hash_String => Source.Hash_String);
   end Copy;

   ------------------
   -- New_Resource --
   --  Purpose: Create a new resource with given name and value
   --  Parameter Name: name of the new resource
   --  Parameter Value: value of the new resource
   --  Returns: the newly created resource
   ------------------

   function New_Resource (Name  : String;
                          Value : Unbounded_String;
                          Boolean_Valued : Boolean;
                          State : Tri_State)
                          return Resource is
      R : Resource;
   begin
      if Name = "h_rt" then
         begin
            R.Numerical := Integer'Value (To_String (Value));
         exception
            when Constraint_Error -- Value is not a number of seconds
               => R.Numerical := Unformat_Duration (To_String (Value));
         end;
         R.Value := To_Unbounded_String (Format_Duration (R.Numerical));
      else
         R.Value := Value;
         R.Numerical := 0;
         R.Boolean_Valued := Boolean_Valued;
         R.State := State;
      end if;
      return R;
   end New_Resource;

   ------------------
   -- New_Resource --
   --  Purpose: Create a new resource with given name and value
   --  Parameter Name: name of the new resource
   --  Parameter Value: value of the new resource
   --  Returns: the newly created resource
   ------------------

   function New_Resource (Name : String; Value : String)
                          return Resource is
      Boolean_Valued : Boolean := False;
      State : Tri_State := Undecided;
   begin
      if Value = "TRUE" then
         Boolean_Valued := True;
         State := True;
      elsif Value = "FALSE" then
         Boolean_Valued := True;
         State := False;
      end if;
      return New_Resource (Name  => Name,
                           Value => To_Unbounded_String (Value),
                           Boolean_Valued => Boolean_Valued,
                           State => State);
   end New_Resource;


   ----------
   -- Hash --
   --  Purpose: Calculate a hash value for a given resource
   --  Parameter R : The resource to consider
   --  Returns: Hash value
   ----------

   function Hash (R : Resource) return Hash_Type is
   begin
      return Hash (R.Value);
   end Hash;


   -------------------------
   -- To_Unbounded_String --
   -------------------------

   function To_Unbounded_String (L : Hashed_List) return Unbounded_String is
      S : Unbounded_String := Null_Unbounded_String;
      Cursor : Resource_Lists.Cursor;
   begin
      if L.Is_Empty then
         return Null_Unbounded_String;
      end if;
      Cursor := L.First;
      loop
         S := S & Key (Cursor) & ": " & Element (Cursor).Value;
         exit when Cursor = L.Last;
         Cursor := Next (Cursor);
         S := S & "; ";
      end loop;
      return S;
   end To_Unbounded_String;

   ---------------
   -- To_String --
   --  Purpose: Convert a Resource_List to a String for output
   ---------------

   function To_String (L : Hashed_List) return String is
   begin
      return To_String (To_Unbounded_String (L));
   end To_String;

   ---------------------
   -- Format_Duration --
   ---------------------

   function Format_Duration (Secs : Natural) return String is
      Days  : Natural;
      Dur   : Duration;
   begin
         Days := Secs / 86400;
         Dur := Ada.Real_Time.To_Duration (Ada.Real_Time.Seconds (Secs - Days * 86400));
         if Days > 0 then
            return Days'Img & "d " & Image (Dur);
         else
            return Image (Dur);
         end if;
   end Format_Duration;



   ---------
   -- "<" --
   ---------

   function "<" (Left, Right : Resource) return Boolean is
   begin
      return Left.Value < Right.Value;
   end "<";

   --------------
   -- Precedes --
   --------------

   function Precedes (Left, Right : Hashed_List) return Boolean is
   begin
      return Left.Hash_Value < Right.Hash_Value;
   end Precedes;

   --------------
   -- To_Model --
   --------------

   function To_Model (S : String) return CPU_Model is
   begin
      if S = "" then
         return none;
      elsif Ada.Strings.Equal_Case_Insensitive (S, "italy") then
         return italy;
      elsif Equal_Case_Insensitive (S, "woodcrest") then
         return woodcrest;
      elsif Equal_Case_Insensitive (S, "clovertown") then
         return clovertown;
      elsif Equal_Case_Insensitive (S, "harpertown") then
         return harpertown;
      elsif Equal_Case_Insensitive (S, "magny-cours") or else
        Equal_Case_Insensitive (S, "magnycours")
      then
         return magnycours;
      elsif Equal_Case_Insensitive (S, "interlagos") then
         return interlagos;
      elsif Equal_Case_Insensitive (S, "ivy-bridge") or else
        Equal_Case_Insensitive (S, "ivybridge")
      then
         return ivybridge;
      elsif S = "sandy-bridge" or else
        Equal_Case_Insensitive (S, "sandybridge")
      then
         return sandybridge;
      elsif S = "abu-dhabi" or else
        Equal_Case_Insensitive (S, "abudhabi")
      then
         return abudhabi;
      elsif Equal_Case_Insensitive (S, "westmere") then
         return westmere;
      elsif Equal_Case_Insensitive (S, "haswell") then
         return haswell;
      else
         raise Constraint_Error with "Unknown CPU model: " & S;
      end if;
   end To_Model;

   function To_Model (S : Unbounded_String) return CPU_Model is
   begin
      return To_Model (To_String (S));
   end To_Model;

   function To_String (Model : CPU_Model) return String is
   begin
      case Model is
         when sandybridge =>
            return "sandy-bridge";
         when ivybridge =>
            return "ivy-bridge";
            when magnycours =>
            return "magny-cours";
         when abudhabi =>
            return "abu-dhabi";
         when others =>
            return Ada.Strings.Fixed.Translate (Source  => Model'Img,
                                                Mapping => Ada.Strings.Maps.Constants.Lower_Case_Map);
      end case;
   end To_String;

   function To_GPU (S : String) return GPU_Model is
   begin
      if S = "" or else
        Equal_Case_Insensitive (S, "none")
      then
         return none;
      elsif Equal_Case_Insensitive (S, "gtx580") then
         return gtx580;
      elsif Equal_Case_Insensitive (S, "gtx680") then
         return gtx680;
      elsif Equal_Case_Insensitive (S, "gtx770") then
         return gtx770;
      elsif Equal_Case_Insensitive (S, "gtx780") then
         return gtx780;
      elsif Equal_Case_Insensitive (S, "gtx780ti") then
         return gtx780ti;
      elsif Equal_Case_Insensitive (S, "gtx980") then
         return gtx980;
      elsif Equal_Case_Insensitive (S, "gtxtitan") then
         return gtxtitan;
      else
         raise Constraint_Error with "Unknown GPU " & S;
      end if;
   end To_GPU;

   function To_GPU (S : Unbounded_String) return GPU_Model is
   begin
      return To_GPU (To_String (S));
   end To_GPU;

   function To_String (GPU : GPU_Model) return String is
   begin
      return Ada.Strings.Fixed.Translate (Source  => GPU'Img,
                                          Mapping => Ada.Strings.Maps.Constants.Lower_Case_Map);
   end To_String;


   ----------------
   -- To_Network --
   --  Purpose : Convert from a String to a Network type
   --  Parameter S: the String to read
   --  returns: The network determined from S
   --  Raises: Constraint_Error if S is not one of "NONE", "IB", "ETH"
   ----------------

   function To_Network (S : String) return Network is
   begin
      if S = "NONE" then
         return none;
      elsif S = "IB" then
         return ib;
      elsif S = "ETH" then
         return eth;
      else
         raise Constraint_Error with "Unknown network " & S;
      end if;
   end To_Network;

   -------------
   -- To_Gigs --
   -------------

   function To_Gigs (Memory : String) return Gigs is
   begin
      if Memory (Memory'Last) = 'G' then
         return Gigs'Value (Memory (Memory'First .. Memory'Last - 1));
      elsif Memory (Memory'Last) = 'M' then
         return Gigs'Value (Memory (Memory'First .. Memory'Last - 1)) / 1024.0;
      else
         raise Constraint_Error with "unknown memory encountered: " & Memory;
      end if;
   end To_Gigs;

   function To_String (Memory : Gigs) return String is
   begin
      return Ada.Strings.Fixed.Trim (Source => Memory'Img,
                                     Side   => Ada.Strings.Right);
   end To_String;

   ------------
   -- Insert --
   ------------

   overriding procedure Insert
     (Container : in out Hashed_List;
      Key       : Unbounded_String;
      New_Item  : Resource;
      Position  : out Resource_Lists.Cursor;
      Inserted  : out Boolean) is
   begin
      Resource_Lists.Insert (Container => Map (Container),
                     Key       => Key,
                     New_Item  => New_Item,
                     Position  => Position,
                     Inserted  => Inserted);
      if Inserted then
         Container.Hash_Value := Container.Hash_Value
         xor Hash (Key)
         xor Hash (New_Item);
         Container.Hash_String := To_Hash_String (Container.Hash_Value'Img);
      end if;
   end Insert;

   ------------
   -- Insert --
   ------------

   overriding procedure Insert
     (Container : in out Hashed_List;
      Key       : Unbounded_String;
      Position  : out Resource_Lists.Cursor;
      Inserted  : out Boolean) is
   begin
      Resource_Lists.Insert (Container => Map (Container),
                  Key       => Key,
                  Position  => Position,
                  Inserted  => Inserted);
      if Inserted then
         Container.Rehash;
      end if;
   end Insert;

   ------------
   -- Insert --
   ------------

   overriding procedure Insert
     (Container : in out Hashed_List;
      Key       : Unbounded_String;
      New_Item  : Resource) is
   begin
      Resource_Lists.Insert (Container => Map (Container),
                  Key       => Key,
                  New_Item  => New_Item);
      Container.Hash_Value := Container.Hash_Value
       xor Hash (Key)
       xor Hash (New_Item);
      Container.Hash_String := To_Hash_String (Container.Hash_Value'Img);
   end Insert;

   -------------
   -- Include --
   -------------

   overriding procedure Include
     (Container : in out Hashed_List;
      Key       : Unbounded_String;
      New_Item  : Resource) is
   begin
      Resource_Lists.Include (Container => Map (Container),
                              Key       => Key,
                              New_Item  => New_Item);
      Container.Rehash;
   end Include;

   ----------
   -- Hash --
   ----------

   function Hash (List : Hashed_List) return String is
   begin
      return To_String (List.Hash_String);
   end Hash;

   -----------
   -- Value --
   -----------

   function Value (L : Hashed_List; Name : String) return String is
   begin
      return To_String (L.Element (Key => To_Unbounded_String (Name)).Value);
   end Value;

   ---------------
   -- Numerical --
   ---------------

   function Numerical (L : Hashed_List; Name : String) return Integer is
   begin
      return L.Element (Key => To_Unbounded_String (Name)).Numerical;
   end Numerical;

   ------------
   -- Rehash --
   ------------

   procedure Rehash (List : in out Hashed_List) is
      Temp : Ada.Containers.Hash_Type := 0;
      Pos : Resource_Lists.Cursor := List.First;
   begin
      while Pos /= Resource_Lists.No_Element loop
         Temp := Temp xor Hash (Element (Pos)) xor Hash (Key (Pos));
         Next (Pos);
      end loop;
      List.Hash_String := To_Hash_String (Temp'Img);
      List.Hash_Value := Temp;
   end Rehash;

   function Unformat_Duration (Dur : String) return Natural is
      Seconds : Natural := 0;

      procedure Extract_HMS (Time : String) is
         T : String (1 .. 8);
      begin
         T (1 .. Time'Length) := Time;
         Seconds := Seconds + Integer'Value (T (7 .. 8));
         Seconds := Seconds + 60 * Integer'Value (T (4 .. 5));
         Seconds := Seconds + 3_600 * Integer'Value (T (1 .. 2));
      end Extract_HMS;

   begin
      if Dur'Length = 8 then
         Extract_HMS (Dur);
      elsif Dur'Length = 10 then
         if Dur (Dur'First + 1) /= ':' then
            raise Constraint_Error with "':' expected at second position of " & Dur;
         end if;
         Extract_HMS (Dur (Dur'First + 2 .. Dur'Last));
         Seconds := Seconds + 86_400 * Integer'Value (Dur (Dur'First .. Dur'First));
      elsif Dur'Length = 11 then
         if Dur (Dur'First + 2) /= ':' then
            raise Constraint_Error with "':' expected at third position of " & Dur;
         end if;
         Extract_HMS (Dur (Dur'First + 3 .. Dur'Last));
         Seconds := Seconds + 86_400 * Integer'Value (Dur (Dur'First .. Dur'First + 1));
      else
         raise Constraint_Error with Dur & " has unexpected length";
      end if;
      return Seconds;
   end Unformat_Duration;

end SGE.Resources;
