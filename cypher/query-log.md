# DELTE all nodes with relationship
```
MATCH (n)
DETACH DELETE n
```

# Display constraints
```
CALL db.constraints;
```

# Constraint
```
CREATE CONSTRAINT unique_course_id ON (c:Course) ASSERT c.course_id IS UNIQUE;
CREATE CONSTRAINT unique_learner_id ON (l:Learner) ASSERT l.learner_id IS UNIQUE;
CREATE CONSTRAINT unique_enrollment_id ON (e:Enrollment) ASSERT e.enrollment_id IS UNIQUE;
CREATE CONSTRAINT unique_course_module_id ON (m:Module) ASSERT m.module_id IS UNIQUE;
CREATE CONSTRAINT unique_module_object_id ON (o:ModuleObject) ASSERT o.object_id IS UNIQUE;
```

## Create Course node
```
LOAD CSV WITH HEADERS FROM "file:///course_date.csv" AS row
WITH row, DATE(row.`from`) AS date_from, DATE(row.`to`) AS date_to

CREATE (c:Course {course_id: row.`course_id`, open_from: date_from, close_at: date_to});
```

## Create Learner enrollment with course

```
LOAD CSV WITH HEADERS FROM
"file:///course_enrollment.csv" AS row
WITH row
MATCH (c:Course {course_id: row.`course_id`})
MERGE (e:Enrollment {enrollment_id: row.`enrollment_id`})
MERGE (l:Learner {learner_id: row.`username`})

CREATE (l)-[:PERFORMED]->(e)-[:ENROLL]->(c);
```

## Set enrollment label
```
LOAD CSV FROM
"file:///enrollment_labelled.csv" AS row
WITH row

MATCH (e:Enrollment {enrollment_id: row[0]})
SET e.learning_status = CASE row[1] WHEN "1" THEN "dropout" ELSE "learn" END;
```

## Create Couse module and it's objects
```
LOAD CSV WITH HEADERS FROM "file:///course_module_objects.csv" AS row
WITH row, SPLIT(TRIM(row.`children`), " ") AS children
MATCH (c:Course {course_id: row.`course_id`})
MERGE (m:Module {module_id: row.`module_id`, category: row.`category`, start_date: row.`start`})

CREATE (c)<-[:PART_OF]-(m)

WITH m, children
UNWIND children AS k
    MERGE (o:ModuleObject {object_id: k})
    CREATE (m)<-[:PART_OF]-(o);
```


## Dropout query
```
match n = (:Learner)-[:PERFORMED]->(:Enrollment {learning_status: "dropout"})-[:ENROLL]->(:Course)-[:HAS]->(:Module)-[:CONTAIN]->(:ModuleObject)
return n
limit 200
```

## Learner participate with course module
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

## Learner participate with course module's object
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


# Create Index
```
CREATE INDEX 
FOR (e:Enrollment)
ON (e.enrollment_id, e.learning_status)

```

# Analytics

## Create graph
```
CALL gds.graph.create.cypher(
    'student-graph',
    // nodeQuery
    'MATCH (n) RETURN id(n) AS id',
    'MATCH (n)-[r]->(m) RETURN id(n) AS source, id(m) AS target, type(r) AS type'
)
```

# Node counting
## All learner
```
MATCH (l:Learner)-[r]->(e:Enrollment)
RETURN COUNT(DISTINCT l)
```

## Dropout learner
```
MATCH (l:Learner)-[r]->(e:Enrollment {learning_status: "dropout"})
RETURN COUNT(DISTINCT l)
```