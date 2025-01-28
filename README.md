# Pipeline & Non-pipeline MIPS Verilog
**1. Abstract**  
The final project for the Computer Organization course involves implementing a Non-Pipeline MIPS CPU architecture as well as a Pipeline MIPS CPU architecture. The project is based on the provided modules: `TESTBED.v`, `TESTBED_p.v`, along with partially completed main CPU modules SP.v and SP_pipeline.v. Additionally, it includes the result verification modules `PATTERN.v` and `PATTERN_p.v`. The task is to complete the remaining parts of the modules, use iVerilog to compile and execute them, and ensure the correctness of the implementation.  

---
**2. Method**  
In the following implementation, I will first work on the Non-Pipeline MIPS architecture, starting with the completion of `SP.v` (including Decode, Memory Read/Write, Register Read/Write, etc.). Once `SP.v` is completed, I will design `PATTERN.v` to perform the corresponding checks.  
After completing the Non-Pipeline implementation, I will move on to the Pipeline architecture, starting with the design of `SP_pipeline.v` (covering the IF, ID, EX, MEM, and WB stages). Similarly, I will then work on `PATTERN_p.v` to verify the results of the Pipeline implementation.

---
**3. Non-pipeline Architecture**  

<img width="684" alt="NonPipelineMIPS" src="https://github.com/user-attachments/assets/26738fa9-f978-44ab-b26b-c6d74e79a551">

---
**4. Pipeline Architecture**

<img width="900" alt="PipelineMIPS" src="https://github.com/user-attachments/assets/3a4867b3-77f0-4527-bdce-e3d2cd0f6472">
