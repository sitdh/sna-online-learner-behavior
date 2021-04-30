// Create constraints
CREATE CONSTRAINT course_uniqueness ON (c:Course) ASSERT c.course_id IS UNIQUE;
CREATE CONSTRAINT enrollment_uniqueness ON (e:Enrollment) ASSERT e.enrollment_id IS UNIQUE;
CREATE CONSTRAINT learner_uniqueness ON (u:Learner) ASSERT u.user_id IS UNIQUE;
CREATE CONSTRAINT course_module_uniqueness ON (m:CourseModule) ASSERT m.module_id IS UNIQUE;
CREATE CONSTRAINT category_uniqueness ON (ct:Category) ASSERT ct.category_id IS UNIQUE;

LOAD CSV WITH HEADERS FROM
'file:///course_date.csv' AS row
WITH row, SPLIT(row.`from`, '-') AS from_date, SPLIT(row.`to`, '-') AS to_date

CREATE (course:Course {id: row.`course_id`})
SET course.from_year = TOINTEGER(from_date[0]),
    course.from_month = TOINTEGER(from_date[1]),
    course.from_date = TOINTEGER(from_date[2]),
    course.to_year = TOINTEGER(to_date[0]),
    course.to_month = TOINTEGER(to_date[1]),
    course.to_date = TOINTEGER(to_date[2])
;