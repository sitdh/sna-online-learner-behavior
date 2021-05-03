# โครงงานประจำภาค วิชา Social Network Analysis

จุดประสงค์เพื่อหาพฤติกรรมคล้ายคลึงกันสำหรับผู้เรียนผ่าน MOOCs (Massive Open Online Courses) 
เพื่อวิเคราะห์ว่าผู้เรียนคนดังกล่าวอยู่ในกลุ่มที่มีแนวโน้มว่าจะยุติการเรียนกลางคัน (Dropout) 
ก่อนที่จะศึกษาเนื้อหาครบตามโครงสร้างหลักสูตรหรือไม่ 

## สิ่งที่ต้องการ 

1. __ชุดข้อมูล (Dataset)__: เป็นชุดข้อมูลผู้เรียน ซึ่งเป็นชุดข้อมูลที่เก็บจากการใช้งานจริงของ MOOCs จัดเก็บโดย[มหาวิทยาลัย Stanford](https://snap.stanford.edu/data/act-mooc.html)
1. __Neo4J Desktop__: ใช้ Ne04j Community ได้ โดยเวอร์ชันขณะศึกษาอยู่ที่เวอร์ชัน 1.4.4 โดยต้องการส่วนขยาย (Plugin) 2 รายการด้วยกัน โดยติดตั้งหลังจากสร้างฐานข้อมูล
    * APOC คือชุดคำสั่งเพิ่มเติมเพื่อวิเคราะห์ข้อมูล
    * Graph Data Science Library คือ เครื่องเมือสำหรับใช้คำสั่งประมวลผลทางด้าน Data Science ได้ (ติดตั้งได้หลังจากที่สั่งเริ่มต้นการทำงานของเซิร์ฟเวอร์ หากเวอร์ชันต่ำกว่า 1.4.4 สามารถติดตั้งได้ทันที่หลังจากสร้างฐานข้อมูลเสร็จ)

## วิธีการติดตั้ง
1. __สร้างฐานข้อมูล__: โดยสร้างแบบ Local DBMS หลังจากนั้นให้แก้ไขค่า `Settings` 2 ค่าดังนี้
    * `dbms.memory.heap.initial_size`: ให้เปลี่ยนจากค่าเดิมเป็น `2G`
    * `dbms.memory.heap.max_size`: เปลี่ยนค่าความจำ (Memory) ที่จะใช้งานให้เพิ่มมากขึ้น แนะนำที่ `4G` แต่ไม่ควรกำหนดค่าให้มากกว่าจำนวนที่มีในเครื่อง
1. __จัดเตรียมชุดข้อมูล__: ให้แตกไฟล์ `sna-moock.dataset.7z` (`dataset/sna-mooc.dataset.7z`) (`dataset`) จะได้ไฟล์นามสกุล `csv` เกิดขึ้นมาภายในโฟลเดอร์ที่จัดเตรียมไว้ 
    * ใน Neo4j ให้เลือกปุ่ม 3 จุด ด้านขวาสุดของมุ่ม `Open` ในฐานข้อมูลที่ต้องการจัดเตรียมข้อมูล แล้วเลือกที่เมนู `Open folder > Import`
    * นำไฟล์ `csv` ที่เตรียมไว้ก่อนหน้านี้ทั้งหมดมาใส่ไว้ภายในโฟลเดอร์ที่ `import`
1. __สร้างกราฟ__: ในขั้นตอนนี้จะแบ่งเป็นส่วนย่อยๆ ดังนี้
    * กำหนดเงื่อนไข (_Constrain_) ในการสร้างโหนด เพื่อป้องกันไม่ให้ `id` ของโหนดต่างๆ ซ้ำกัน
        ```
        CREATE CONSTRAINT unique_course_id ON (c:Course) ASSERT c.course_id IS UNIQUE;
        CREATE CONSTRAINT unique_learner_id ON (l:Learner) ASSERT l.learner_id IS UNIQUE;
        CREATE CONSTRAINT unique_enrollment_id ON (e:Enrollment) ASSERT e.enrollment_id IS UNIQUE;
        CREATE CONSTRAINT unique_course_module_id ON (m:Module) ASSERT m.module_id IS UNIQUE;
        CREATE CONSTRAINT unique_module_object_id ON (o:ModuleObject) ASSERT o.object_id IS UNIQUE;
        ```
    * สร้างโหนดของหลักสูตร (`Course`) โดยอ่านจากไฟล์ `course_date.csv` 
        ```
        LOAD CSV WITH HEADERS FROM "file:///course_date.csv" AS row
        WITH row, DATE(row.`from`) AS date_from, DATE(row.`to`) AS date_to

        CREATE (c:Course {course_id: row.`course_id`, open_from: date_from, close_at: date_to});
        ```
    * สร้างโหนดการลงทะเบียน (`Enrollment`) ด้วยข้อมูลจากไฟล์ `course_enrollment.csv` เพื่อใช้จัดเก็บพฤติกรรมการลงทะเบียนแต่ละวิชาของผู้เรียน
        ```
        LOAD CSV WITH HEADERS FROM
        "file:///course_enrollment.csv" AS row
        WITH row
        MATCH (c:Course {course_id: row.`course_id`})
        MERGE (e:Enrollment {enrollment_id: row.`enrollment_id`})
        MERGE (l:Learner {learner_id: row.`username`})

        CREATE (l)-[:PERFORMED]->(e)-[:ENROLL]->(c);
        ```
    * ใส่ป้ายกำกับ (property) ให้กับโหนดการลงทะเบียน เพื่อใช้แบ่งแยกว่าการลงทะเบียนใดบ้างเป็นการลงทะเบียนที่ผู้เรียนมีพฤติกรรมยุติการเรียนกลางคัน
        ```
        LOAD CSV FROM
        "file:///enrollment_labelled.csv" AS row
        WITH row

        MATCH (e:Enrollment {enrollment_id: row[0]})
        SET e.learning_status = CASE row[1] WHEN "1" THEN "dropout" ELSE "learn" END;
        ```
    * เพิ่มโหนดส่วนประกอบหลักสูตร (`Module` และ `ModuleObject`) ซึ่งเป็นเนื้อหาที่อยู่ในหลักสูตร เพื่อช่วยให้ผู้สอนใช้แบ่งแยกเนื้อหาในหลักสูตรนั้นให้เป็นสัดส่วน
        ```
        LOAD CSV WITH HEADERS FROM "file:///course_module_objects.csv" AS row
        WITH row, SPLIT(TRIM(row.`children`), " ") AS children
        MATCH (c:Course {course_id: row.`course_id`})
        MERGE (m:Module {module_id: row.`module_id`, category: row.`category`, start_date: row.`start`})

        CREATE (c)-[:HAS]->(m)

        WITH m, children
        UNWIND children AS k
            MERGE (o:ModuleObject {object_id: k})
            CREATE (m)-[:CONTAIN]->(o);
        ```
    * เพิ่มความสัมพันธ์ของผู้เรียนและเนื้อหาในบทเรียน แบ่งออกเป็น 2 ส่วนด้วยกัน นั่นคือ (`:Enrollment`)--(`:Event`)--(`:Module`) และ (`:Enrollment`)--(`:Event`)--(`:ModuleObject`) 
    ```
    :auto USING PERIODIC COMMIT
    LOAD CSV WITH HEADERS FROM "file:///course_object_participation.csv" AS row
    WITH row, DATETIME(row.`time`) AS ts

    MATCH (o:ModuleObject {object_id: row.`object`})
    MATCH (e:Enrollment {enrollment_id: row.`enrollment_id`})
    CREATE (
        ev:Event 
        {
            action: row.`event`,
            timestamp: ts,
            source: row.`source`
        }
    )

    CREATE (e)-[:ACTION]->(ev)-[:PARTICIPATE]->(o);
    ```
    และ
    ```
    :auto USING PERIODIC COMMIT
    LOAD CSV WITH HEADERS FROM "file:///course_object_participation.csv" AS row
    WITH row, DATETIME(row.`time`) AS ts

    MATCH (m:Module {module_id: row.`object`})
    MATCH (e:Enrollment {enrollment_id: row.`enrollment_id`})
    CREATE (
        ev:Event 
        {
            action: row.`event`,
            timestamp: ts,
            source: row.`source`
        }
    )

    CREATE (e)-[:ACTION]->(ev)-[:PARTICIPATE]->(m);
    ```

    จะเห็นได้ว่าคำสั่งทั้ง 2 นี้เพิ่มคำสั่ง `:auto USING PERIODIC COMMIT` ไว้ที่บันทัดแรก เนื่องจากจำนวนโหนดที่สร้างขึ้นด้วยขั้นตอนนี้จากทั้ง 2 คำสั่งมีจำนวนมาก ดังนั้น เพื่อให้โปรแกรมบันทึกโหนดที่สร้างขึ้นเป็นระยะๆ ทำให้เครื่องที่มีหน่วยความจำตามที่แนะนำสามารถประมวลผลคำสั่งนี้ได้ หากไม่ใส่จำเป็นจะต้องปรับค่า `dbms.memory.heap.max_size=12G` เพื่อใช้หน่วยความจำขนาด 12GB เพื่อทำงาน
1. คำสั่งสรุปข้อมูลเบื้องต้น
    * สรุปจำนวนโหนดโดยแบ่งตามป้ายกำกับ 
        ```
        MATCH (n) 
        RETURN DISTINCT count(labels(n)) AS node_count, labels(n)[0] AS node_name;
        ```
        __ตัวอย่างผลลัพธ์__
        | node_count | node_name |
        | ---------: | --------: |
        | 39         | Course    |
        | 72         | Enrollment| 
        | 53,870     | Learner   | 
    * จำนวนการลงทะเบียนที่ผู้เรียนที่ยุติการเรียนกลางคัน
        ```
        MATCH (:Enrollment {learning_status: "dropout"})
        RETURN COUNT(e) AS total_dropout;
        ```
        __ตัวอย่างผลลัพธ์__
        | total_dropout |
        | ------------: |
        | 72,395        |
    * หลักสูตรที่ผู้มีผู้เรียนยุติการเรียนกลางคันไปมากที่สุด พร้อมทั้งจำนวน โดนเรียงจากมากที่สุดไปน้อยที่สุด เฉพาะ 10 อันดับแรก
        ```
        MATCH (:Enrollment {learning_status: "dropout"})--(e:Event)--()-[:PART_OF]-(c:Course)
        RETURN c.course_id AS course_id, count(e) AS number_of_event
        ORDER BY number_of_event DESC;
        ```
        __ตัวอย่างผลลัพธ์__
        | course_id                         | number_of_event |
        | ---------:                        | --------: |
        | DPnLzkJJqOOPRJfBxIHbQEERiYHu5ila  | 87,653    |
        | I7Go4XwWgpjRJM8EZGEnBpkfSmBNOlsO  | 86,161    |
        | shM3Yy9vxHn2aqjSYfQXOcwGo0hWh3MI  | 65,276    |
    * โครงสร้างของหลักสูตร ซึ่งในที่นี้จะดึงโครงสร้างเนื้อหาของหลักสูตรที่มีผู้เรียนยุติการเรียนกลางคันออกมา ดังข้อมูลที่แสดงในตารางก่อนหน้า
        ```
        MATCH (c:Course {course_id: "DPnLzkJJqOOPRJfBxIHbQEERiYHu5ila"})-[:PART_OF]-(n)-[:PART_OF]-(m)
        WHERE labels(n)[0] IN ["Module", "ModuleObject"]
            OR labels(m)[0] = "ModuleObject"
        RETURN c, m, n
        ```
        __ตัวอย่างผลลัพธ์__  
        _<ไม่มีตัวอย่างข้อมูล เนื่องจากเป็นกราฟ>_

## รายงานฉบับเต็ม
ในการศึกษาวิจัยครั้งนี้ได้จัดทำรายงานการวิจัยเพื่อบันทึกการดำเนินงานไว้ สามารถเข้าถึงได้ได้ที่ ไฟล์ sna-learner-behavior.pdf ([pdf](./docs/report/sna-learner-behavior.pdf), [LaTeX](./docs/report/sna-learner-behavior.tex) ในโฟลเดอร์ [`docs/report`](./docs/report)