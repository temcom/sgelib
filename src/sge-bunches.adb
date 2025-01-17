with Ada.Containers.Doubly_Linked_Lists;
with SGE.Jobs; use SGE.Jobs;
with SGE.Ranges; use SGE.Ranges; use SGE.Ranges.Range_Lists;
with Ada.Text_IO;
with SGE.Resources; use SGE.Resources; use SGE.Resources.Resource_Lists;
with Ada.Exceptions;

package body SGE.Bunches is

   function Init_CPU_Slots (J : Job) return String;
   function Init_GPU_Slots (J : Job) return String;

   ----------------
   -- Build_List --
   ----------------

   procedure Build_List is
      B : Bunch;
      J : Job;
   begin
      Jobs.Sort;
      Jobs.Rewind;

      if Jobs.Empty then
         Ada.Text_IO.Put_Line ("<i>No jobs found</i>");
      else
         J := Jobs.Current;
         --  Create Bunch according to first Job
         B := New_Bunch (J);
         loop
            --  New Bunch?
            if B /= J then
               --  Yes. Store previous one.
               List.Append (B);
               B := New_Bunch (J);
            end if;

            --  Update totals

            B.Total := B.Total + Get_Task_Count (J);
            if On_Hold (J) then
               B.On_Hold := B.On_Hold + Get_Task_Count (J);
            elsif Has_Error (J) then
               B.Error := B.Error + Get_Task_Count (J);
            elsif  Quota_Inhibited (J) then
               B.Quota_Inhibited := B.Quota_Inhibited + Get_Task_Count (J);
            else
               B.Waiting := B.Waiting + Get_Task_Count (J);
            end if;
            exit when Jobs.At_End;
            --  Advance
            J := Jobs.Next;
         end loop;
         --  That's it. Store final bunch.
         List.Append (B);
      end if;
   exception
      when E : Constraint_Error
         => raise Other_Error with "Unable to build bunch while examining job"
                        & Get_ID (J)
                       & ": " & Ada.Exceptions.Exception_Message (E);
   end Build_List;

   function Get_CPU_Slot_Numbers (B : Bunch) return String is
   begin
      return To_String (B.CPU_Slot_List);
   end Get_CPU_Slot_Numbers;

   function Get_GPU_Slot_Numbers (B : Bunch) return String is
   begin
      return To_String (B.GPU_Slot_List);
   end Get_GPU_Slot_Numbers;

   function Init_CPU_Slots (J : Job) return String is
   begin
      if not Get_Hard_Resources (J).Contains (To_Unbounded_String ("gpu")) then
         return To_String (J.Get_Slot_List, Short => True);
      elsif Supports_Balancer (J, CPU_GPU) then
         return J.Get_CPU_Range;
      else
         return "";
      end if;
   end Init_CPU_Slots;

   function Init_GPU_Slots (J : Job) return String is
   begin
      if Get_Hard_Resources (J).Contains (To_Unbounded_String ("gpu")) then
         return To_String (J.Get_Slot_List, Short => True);
      elsif Supports_Balancer (J, CPU_GPU) then
         return J.Get_GPU_Range;
      else
         return "";
      end if;
   end Init_GPU_Slots;

   function Is_Queued_For_GPU (B : Bunch) return Boolean is
   begin
      return B.Hard.Contains (To_Unbounded_String ("gpu"));
   end Is_Queued_For_GPU;

   -------------------
   -- New_Bunch --
   -------------------

   function New_Bunch (J : Job) return Bunch is
      B : Bunch;
   begin
      B.PE          := Get_PE (J);
      B.Slot_List   := Get_Slot_List (J);
      B.Slot_Number := Get_Slot_Number (J);
      B.CPU_Slot_List := To_Unbounded_String (Init_CPU_Slots (J));
      B.GPU_Slot_List := To_Unbounded_String (Init_GPU_Slots (J));
      B.Queue       := Get_Queue (J);
      B.Hard        := Get_Hard_Resources (J);
      B.Soft        := Get_Soft_Resources (J);
      for Capability in Balancer_Support'Range loop
         B.Balancer (Capability) := Supports_Balancer (J, Capability);
      end loop;
      B.Total       := 0;
      B.On_Hold     := 0;
      B.Waiting     := 0;
      B.Quota_Inhibited := 0;
      B.Error       := 0;
      return B;
   end New_Bunch;


   ---------
   -- "=" --
   ---------

   function "=" (Left : Job; Right : Bunch) return Boolean is
   begin
      return Right = Left;
   end "=";

   ---------
   -- "=" --
   ---------

   function "=" (Left : Bunch; Right : Job) return Boolean is
   begin
      for Capability in Balancer_Support'Range loop
         if Left.Balancer (Capability) /= Supports_Balancer (Right, Capability) then
            return False;
         end if;
      end loop;
      return (Left.PE = Get_PE (Right) and then
                   Left.Slot_Number = Get_Slot_Number (Right) and then
                   Left.Slot_List = Get_Slot_List (Right) and then
                   Left.Hard = Get_Hard_Resources (Right) and then
                   Left.Soft = Get_Soft_Resources (Right) and then
                   Left.Queue = Get_Queue (Right));
   end "=";

   procedure Iterate (Process : access procedure (B : Bunch)) is
      procedure Wrapper (Pos : Bunch_Lists.Cursor) is
      begin
         Process (Bunch_Lists.Element (Pos));
      end Wrapper;
   begin
      Bunch_Lists.Iterate (List, Wrapper'Access);
   end Iterate;

   function Has_Error (B : Bunch) return Boolean is
   begin
      return B.Error > 0;
   end Has_Error;

   function Has_Waiting (B : Bunch) return Boolean is
   begin
      return B.Waiting > 0;
   end Has_Waiting;

   function Get_PE (B : Bunch) return String is
   begin
      return To_String (B.PE);
   end Get_PE;

   function Get_Slot_Numbers (B : Bunch) return String is
   begin
      if B.Slot_List.Is_Empty then
         return To_String (B.Slot_Number);
      else
         return To_String (B.Slot_List, Short => True);
      end if;
   end Get_Slot_Numbers;

   function Get_Slot_Number (B : Bunch) return String is
   begin
      return To_String (B.Slot_Number);
   end Get_Slot_Number;

   function Get_Queue (B : Bunch) return String is
   begin
      return To_String (B.Queue);
   end Get_Queue;

   function Get_Total_Jobs (B : Bunch) return Natural is
   begin
      return B.Total;
   end Get_Total_Jobs;

   function Get_Waiting_Jobs (B : Bunch) return Natural is
   begin
      return B.Waiting;
   end Get_Waiting_Jobs;

   function Get_Errors (B : Bunch) return Natural is
   begin
      return B.Error;
   end Get_Errors;

   function Get_Jobs_On_Hold (B : Bunch) return Natural is
   begin
      return B.On_Hold;
   end Get_Jobs_On_Hold;

   function Get_Quota_Inhibited_Jobs (B : Bunch) return Natural is
   begin
      return B.Quota_Inhibited;
   end Get_Quota_Inhibited_Jobs;

   function Has_Balancer (B : Bunch; Capability : Balancer_Capability) return Boolean is
   begin
      return B.Balancer (Capability);
   end Has_Balancer;

   function Get_Hard_Resources (B : Bunch) return String is
   begin
      return To_String (B.Hard);
   end Get_Hard_Resources;

   function Get_Soft_Resources (B : Bunch) return String is
   begin
      return To_String (B.Soft);
   end Get_Soft_Resources;

   function Get_Slot_Hash (B : Bunch) return String is
   begin
      return Hash (B.Slot_List);
   end Get_Slot_Hash;

   function Get_Hard_Hash (B : Bunch) return String is
   begin
      return Hash (B.Hard);
   end Get_Hard_Hash;

   function Get_Soft_Hash (B : Bunch) return String is
   begin
      return Hash (B.Soft);
   end Get_Soft_Hash;



end SGE.Bunches;
